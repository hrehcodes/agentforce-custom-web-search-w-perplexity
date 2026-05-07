@IsTest
private class Web_Search_w_Perplexity_Search_Test {

    // Captured request so we can assert on the serialized body/endpoint
    private static HttpRequest lastReq;
    private static String lastBody;

    // Simple capturing mock (always returns the provided code/body)
    private class CapturingMock implements HttpCalloutMock {
        private Integer code;
        private String respBody;
        CapturingMock(Integer code, String body) {
            this.code = code;
            this.respBody = body;
        }
        public HttpResponse respond(HttpRequest req) {
            Web_Search_w_Perplexity_Search_Test.lastReq = req;
            Web_Search_w_Perplexity_Search_Test.lastBody = req.getBody();
            HttpResponse res = new HttpResponse();
            res.setStatusCode(code);
            res.setStatus(String.valueOf(code) + ' STATUS');
            res.setBody(respBody);
            return res;
        }
    }

    // Sequence mock to simulate retries: each int is either a status code or 0 => throw
    private class SequenceMock implements HttpCalloutMock {
        private List<Integer> steps;
        private String successBody;
        SequenceMock(List<Integer> s, String successBody) {
            this.steps = (s == null) ? new List<Integer>() : new List<Integer>(s);
            this.successBody = successBody;
        }
        public HttpResponse respond(HttpRequest req) {
            Web_Search_w_Perplexity_Search_Test.lastReq = req;
            Web_Search_w_Perplexity_Search_Test.lastBody = req.getBody();
            if (steps.isEmpty()) {
                HttpResponse ok = new HttpResponse();
                ok.setStatusCode(200);
                ok.setStatus('200 OK');
                ok.setBody(successBody);
                return ok;
            }
            Integer step = steps[0];
            steps.remove(0);
            if (step == 0) {
                throw new CalloutException('Simulated transport exception');
            }
            HttpResponse res = new HttpResponse();
            res.setStatusCode(step);
            res.setStatus(String.valueOf(step) + ' STATUS');
            res.setBody(step == 200 ? successBody : '{"code":'+String.valueOf(step)+'}');
            return res;
        }
    }

    /* ========== Tests ========== */

    @IsTest
    static void testSingleQuery_Minimal() {
        Test.setMock(HttpCalloutMock.class,
            new CapturingMock(200, '{"results":[{"title":"A","url":"https://a.example"}]}')
        );

        Web_Search_w_Perplexity_Search.Input i = new Web_Search_w_Perplexity_Search.Input();
        i.query = 'hello world';

        Test.startTest();
        List<Web_Search_w_Perplexity_Search.Output> out =
            Web_Search_w_Perplexity_Search.run(new List<Web_Search_w_Perplexity_Search.Input>{ i });
        Test.stopTest();

        System.assertEquals(1, out.size());
        System.assert(out[0].fullJsonResponse.contains('"results"'));

        // Verify endpoint and body
        System.assertEquals('callout:Perplexity_API/search', lastReq.getEndpoint());
        Map<String,Object> sent = (Map<String,Object>) JSON.deserializeUntyped(lastBody);
        System.assertEquals('hello world', (String) sent.get('query'));
        System.assertEquals(false, sent.containsKey('max_results'));
        System.assertEquals(false, sent.containsKey('max_tokens_per_page'));
        System.assertEquals(false, sent.containsKey('country'));
    }

    @IsTest
    static void testMultiQuery_WithParams_ClampedAndNormalized() {
        Test.setMock(HttpCalloutMock.class,
            new CapturingMock(200, '{"ok":true}')
        );

        Web_Search_w_Perplexity_Search.Input i = new Web_Search_w_Perplexity_Search.Input();
        i.query = 'alpha\nbeta\n  \n'; // multi-query (blank line ignored)
        i.maxResults = 25;              // should clamp to 20
        i.maxTokensPerPage = 0;         // should clamp to 1
        i.country = 'us';               // should normalize to US
        i.timeoutMs = 200000;           // should clamp to 120000 by util

        Test.startTest();
        Web_Search_w_Perplexity_Search.run(new List<Web_Search_w_Perplexity_Search.Input>{ i });
        Test.stopTest();

        Map<String,Object> sent = (Map<String,Object>) JSON.deserializeUntyped(lastBody);
        // query should be an array of 2 strings
        List<Object> q = (List<Object>) sent.get('query');
        System.assertEquals(2, q.size());
        System.assertEquals('alpha', (String) q[0]);
        System.assertEquals('beta',  (String) q[1]);

        System.assertEquals(20, (Integer) sent.get('max_results'));            // clamped
        System.assertEquals(1,  (Integer) sent.get('max_tokens_per_page'));    // clamped
        System.assertEquals('US', (String) sent.get('country'));               // normalized
    }

    @IsTest
    static void testBlankQuery_throws() {
        Web_Search_w_Perplexity_Search.Input i = new Web_Search_w_Perplexity_Search.Input();
        i.query = '   ';
        try {
            Test.startTest();
            Web_Search_w_Perplexity_Search.run(new List<Web_Search_w_Perplexity_Search.Input>{ i });
            Test.stopTest();
            System.assert(false, 'Expected IllegalArgumentException for blank query');
        } catch (IllegalArgumentException e) {
            System.assert(e.getMessage().toLowerCase().contains('cannot be blank'));
        }
    }

    @IsTest
    static void testInvalidCountry_throws() {
        Web_Search_w_Perplexity_Search.Input i = new Web_Search_w_Perplexity_Search.Input();
        i.query = 'foo';
        i.country = 'USA'; // invalid ISO-2
        try {
            Test.startTest();
            Web_Search_w_Perplexity_Search.run(new List<Web_Search_w_Perplexity_Search.Input>{ i });
            Test.stopTest();
            System.assert(false, 'Expected IllegalArgumentException for invalid country');
        } catch (IllegalArgumentException e) {
            System.assert(e.getMessage().contains('ISO 3166-1 alpha-2'));
        }
    }

    @IsTest
    static void testRetryThenSuccess() {
        // First response 500, second 200 → should succeed with 200
        Test.setMock(HttpCalloutMock.class,
            new SequenceMock(new List<Integer>{ 500, 200 }, '{"ok":true}')
        );

        Web_Search_w_Perplexity_Search.Input i = new Web_Search_w_Perplexity_Search.Input();
        i.query = 'q';

        Test.startTest();
        List<Web_Search_w_Perplexity_Search.Output> out =
            Web_Search_w_Perplexity_Search.run(new List<Web_Search_w_Perplexity_Search.Input>{ i });
        Test.stopTest();

        System.assertEquals(1, out.size());
        System.assertEquals(true, out[0].fullJsonResponse.contains('"ok":true'));
    }

    @IsTest
    static void testOmitOptionalFieldsWhenNull() {
        Test.setMock(HttpCalloutMock.class,
            new CapturingMock(200, '{"ok":true}')
        );

        Web_Search_w_Perplexity_Search.Input i = new Web_Search_w_Perplexity_Search.Input();
        i.query = 'only query'; // all others null

        Test.startTest();
        Web_Search_w_Perplexity_Search.run(new List<Web_Search_w_Perplexity_Search.Input>{ i });
        Test.stopTest();

        Map<String,Object> sent = (Map<String,Object>) JSON.deserializeUntyped(lastBody);
        System.assertEquals(1, sent.size(), 'Only "query" should be sent when others are null');
        System.assertEquals('only query', (String) sent.get('query'));
    }
}