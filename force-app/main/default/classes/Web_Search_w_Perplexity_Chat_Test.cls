@IsTest
private class Web_Search_w_Perplexity_Chat_Test {

    /* ====== Capturing mocks ====== */

    private static HttpRequest lastReq;
    private static String lastBody;

    private class CapturingMock implements HttpCalloutMock {
        private Integer code;
        private String respBody;
        CapturingMock(Integer code, String body) {
            this.code = code; this.respBody = body;
        }
        public HttpResponse respond(HttpRequest req) {
            Web_Search_w_Perplexity_Chat_Test.lastReq = req;
            Web_Search_w_Perplexity_Chat_Test.lastBody = req.getBody();
            HttpResponse res = new HttpResponse();
            res.setStatusCode(code);
            res.setStatus(String.valueOf(code) + ' STATUS');
            res.setBody(respBody);
            return res;
        }
    }

    private class SequenceMock implements HttpCalloutMock {
        private List<Integer> steps;
        private String successBody;
        SequenceMock(List<Integer> statuses, String successBody) {
            this.steps = (statuses == null) ? new List<Integer>() : new List<Integer>(statuses);
            this.successBody = successBody;
        }
        public HttpResponse respond(HttpRequest req) {
            Web_Search_w_Perplexity_Chat_Test.lastReq = req;
            Web_Search_w_Perplexity_Chat_Test.lastBody = req.getBody();
            if (steps.isEmpty()) {
                HttpResponse ok = new HttpResponse();
                ok.setStatusCode(200);
                ok.setStatus('200 OK');
                ok.setBody(successBody);
                return ok;
            }
            Integer code = steps[0];
            steps.remove(0);
            HttpResponse res = new HttpResponse();
            res.setStatusCode(code);
            res.setStatus(String.valueOf(code) + ' STATUS');
            res.setBody(code == 200 ? successBody : '{"code":'+String.valueOf(code)+'}');
            return res;
        }
    }

    /* ====== Helpers ====== */

    private static Map<String,Object> bodyAsMap() {
        System.assertNotEquals(null, lastBody, 'No body captured; did the callout execute?');
        return (Map<String,Object>) JSON.deserializeUntyped(lastBody);
    }

    private static Map<String,Object> asMap(Object o) { return (Map<String,Object>) o; }
    private static List<Object> asList(Object o) { return (List<Object>) o; }

    /* ====== Tests ====== */

    @IsTest
    static void testMinimalHappyPath_DefaultsApplied() {
        // Mock a normal 200 response
        Test.setMock(HttpCalloutMock.class, new CapturingMock(200, '{"choices":[{"message":{"content":"ok"}}]}'));

        Web_Search_w_Perplexity_Chat.Input i = new Web_Search_w_Perplexity_Chat.Input();
        i.userPrompt = 'What is the capital of France?';
        i.systemPrompt = 'You are concise.';
        i.model = ' '; // should normalize to sonar
        // all other fields omitted

        Test.startTest();
        List<Web_Search_w_Perplexity_Chat.Output> out =
            Web_Search_w_Perplexity_Chat.run(new List<Web_Search_w_Perplexity_Chat.Input>{ i });
        Test.stopTest();

        System.assertEquals(1, out.size());
        System.assert(out[0].fullJsonResponse.contains('"choices"'));

        // Inspect request
        System.assertEquals('callout:Perplexity_API/chat/completions', lastReq.getEndpoint());
        Map<String,Object> sent = bodyAsMap();

        System.assertEquals('sonar', (String) sent.get('model'));         // default model
        System.assertEquals('web',   (String) sent.get('search_mode'));    // default search mode

        List<Object> messages = asList(sent.get('messages'));
        System.assertEquals(2, messages.size());
        System.assertEquals('system', (String) asMap(messages[0]).get('role'));
        System.assertEquals('You are concise.', (String) asMap(messages[0]).get('content'));
        System.assertEquals('user',   (String) asMap(messages[1]).get('role'));
        System.assertEquals('What is the capital of France?', (String) asMap(messages[1]).get('content'));

        System.assertEquals(false, sent.containsKey('web_search_options')); // none provided
    }

    @IsTest
    static void testFullOptions_BodyBuiltAndClamped() {
        Test.setMock(HttpCalloutMock.class, new CapturingMock(200, '{"ok":true}'));

        Web_Search_w_Perplexity_Chat.Input i = new Web_Search_w_Perplexity_Chat.Input();
        // Required
        i.userPrompt = 'Summarize the latest earnings call and cite sources.';
        i.systemPrompt = 'You are a precise research assistant.';

        // Modes / context
        i.model = ' Sonar PRO ';              // → sonar-pro
        i.searchMode = '  SEC ';              // → sec
        i.searchContextSize = ' hi ';         // → high

        // Filters
        i.searchDomainFilter = 'https://www.NASA.gov/path , wikipedia.org/wiki,  NASA.gov  '; // → nasa.gov, wikipedia.org (deduped)
        i.searchRecencyFilter = null;
        i.searchAfterDate = '2025-03-01';     // 3/1/2025
        i.searchBeforeDate = null;
        i.lastUpdatedAfter = null;
        i.lastUpdatedBefore = '3/15/2025';    // 3/15/2025

        i.enableSearchClassifier = true;
        i.disableSearch = true;

        // Tuning
        i.maxTokens = 900;
        i.temperature = Decimal.valueOf('2.5');   // clamp → 1.9999
        i.topP = Decimal.valueOf('-0.2');         // clamp → 0
        i.topK = -1;                              // ignored
        i.presencePenalty = Decimal.valueOf('5'); // clamp → 2
        i.frequencyPenalty = Decimal.valueOf('-3'); // clamp → -2
        i.responseFormatType = 'json';            // → json_object

        // User location under web_search_options
        i.userLocationCountry = 'us';             // → US
        i.userLocationRegion  = 'California';
        i.userLocationCity    = 'San Francisco';

        // Media/Images
        i.returnRelatedQuestions = true;
        i.returnImages = true;
        i.returnVideos = true;
        i.imageDomainFilter = '-Pinterest.com';
        i.imageFormatFilter = 'jpg, tiff, PNG, jpeg'; // keep jpg/png/jpeg; skip tiff

        i.timeoutMs = 200000; // clamp to 120000 (we cannot assert getTimeout reliably, but body assertions suffice)

        Test.startTest();
        Web_Search_w_Perplexity_Chat.run(new List<Web_Search_w_Perplexity_Chat.Input>{ i });
        Test.stopTest();

        Map<String,Object> sent = bodyAsMap();

        // Top-level
        System.assertEquals('sonar-pro', (String) sent.get('model'));
        System.assertEquals('sec',       (String) sent.get('search_mode'));

        // Messages
        List<Object> msgs = asList(sent.get('messages'));
        System.assertEquals(2, msgs.size());

        // Filters
        List<Object> doms = (List<Object>) sent.get('search_domain_filter');
        System.assertEquals(2, doms.size());
        Set<String> domSet = new Set<String>{
            (String)doms[0], (String)doms[1]
        };
        System.assertEquals(true, domSet.contains('nasa.gov'));
        System.assertEquals(true, domSet.contains('wikipedia.org'));

        System.assertEquals('3/1/2025',  (String) sent.get('search_after_date_filter'));
        System.assertEquals('3/15/2025', (String) sent.get('last_updated_before_filter'));
        System.assertEquals(true,        (Boolean) sent.get('enable_search_classifier'));
        System.assertEquals(true,        (Boolean) sent.get('disable_search'));

        // Tuning
        System.assertEquals(900, (Integer) sent.get('max_tokens'));
        System.assertEquals(Decimal.valueOf('1.9999'), (Decimal) sent.get('temperature'));
        System.assertEquals(Decimal.valueOf('0'), (Decimal) sent.get('top_p'));
        System.assertEquals(false, sent.containsKey('top_k')); // -1 ignored
        System.assertEquals(Decimal.valueOf('2'),  (Decimal) sent.get('presence_penalty'));
        System.assertEquals(Decimal.valueOf('-2'), (Decimal) sent.get('frequency_penalty'));

        // Response format
        Map<String,Object> rf = asMap(sent.get('response_format'));
        System.assertEquals('json_object', (String) rf.get('type'));

        // web_search_options
        Map<String,Object> ws = asMap(sent.get('web_search_options'));
        System.assertEquals('high', (String) ws.get('search_context_size'));
        Map<String,Object> loc = asMap(ws.get('user_location'));
        System.assertEquals('US',          (String) loc.get('country'));
        System.assertEquals('California',  (String) loc.get('region'));
        System.assertEquals('San Francisco', (String) loc.get('city'));

        // media_response
        Map<String,Object> mr = asMap(sent.get('media_response'));
        Map<String,Object> ovr = asMap(mr.get('overrides'));
        System.assertEquals(true, (Boolean) ovr.get('return_images'));
        System.assertEquals(true, (Boolean) ovr.get('return_videos'));

        // image filters
        List<Object> imgDom = (List<Object>) sent.get('image_domain_filter');
        System.assertEquals(1, imgDom.size());
        System.assertEquals('-pinterest.com', (String) imgDom[0]);

        List<Object> imgFmt = (List<Object>) sent.get('image_format_filter');
        Set<String> fmtSet = new Set<String>();
        for (Object x : imgFmt) fmtSet.add((String)x);
        System.assertEquals(true, fmtSet.contains('jpg') || fmtSet.contains('jpeg')); // we allow both
        System.assertEquals(true, fmtSet.contains('png'));
        System.assertEquals(false, fmtSet.contains('tiff')); // skipped

        // related questions
        System.assertEquals(true, (Boolean) sent.get('return_related_questions'));
    }

    @IsTest
    static void testRecencyVsDatesThrows() {
        Web_Search_w_Perplexity_Chat.Input i = new Web_Search_w_Perplexity_Chat.Input();
        i.userPrompt = 'x';
        i.systemPrompt = 'y';
        i.searchRecencyFilter = 'week';
        i.searchAfterDate = '2025-01-01';
        try {
            Test.startTest();
            Web_Search_w_Perplexity_Chat.run(new List<Web_Search_w_Perplexity_Chat.Input>{ i });
            Test.stopTest();
            System.assert(false, 'Expected IllegalArgumentException due to recency+dates conflict');
        } catch (IllegalArgumentException e) {
            System.assert(e.getMessage().toLowerCase().contains('recency') && e.getMessage().toLowerCase().contains('cannot'));
        }
    }

    @IsTest
    static void testMixedAllowDenyDomainsThrows() {
        Web_Search_w_Perplexity_Chat.Input i = new Web_Search_w_Perplexity_Chat.Input();
        i.userPrompt = 'x';
        i.systemPrompt = 'y';
        i.searchDomainFilter = 'nasa.gov, -wikipedia.org';
        try {
            Test.startTest();
            Web_Search_w_Perplexity_Chat.run(new List<Web_Search_w_Perplexity_Chat.Input>{ i });
            Test.stopTest();
            System.assert(false, 'Expected IllegalArgumentException for mixed allow/deny list');
        } catch (IllegalArgumentException e) {
            System.assert(e.getMessage().contains('cannot mix allowlist and denylist'));
        }
    }

    @IsTest
    static void testInvalidUserLocationCountryThrows() {
        Web_Search_w_Perplexity_Chat.Input i = new Web_Search_w_Perplexity_Chat.Input();
        i.userPrompt = 'x';
        i.systemPrompt = 'y';
        i.userLocationCountry = 'USA'; // invalid ISO-2 → normalizeCountry throws
        try {
            Test.startTest();
            Web_Search_w_Perplexity_Chat.run(new List<Web_Search_w_Perplexity_Chat.Input>{ i });
            Test.stopTest();
            System.assert(false, 'Expected IllegalArgumentException for invalid country');
        } catch (IllegalArgumentException e) {
            System.assert(e.getMessage().contains('ISO 3166-1 alpha-2'));
        }
    }

    @IsTest
    static void testRetryThenSuccess() {
        // First 500, then 200
        Test.setMock(HttpCalloutMock.class, new SequenceMock(new List<Integer>{ 500, 200 }, '{"ok":true}'));

        Web_Search_w_Perplexity_Chat.Input i = new Web_Search_w_Perplexity_Chat.Input();
        i.userPrompt = 'q';
        i.systemPrompt = 'sys';

        Test.startTest();
        List<Web_Search_w_Perplexity_Chat.Output> out =
            Web_Search_w_Perplexity_Chat.run(new List<Web_Search_w_Perplexity_Chat.Input>{ i });
        Test.stopTest();

        System.assertEquals(1, out.size());
        System.assertEquals(true, out[0].fullJsonResponse.contains('"ok":true'));
    }

    @IsTest
    static void testMissingRequiredsThrow() {
        // Missing userPrompt
        Web_Search_w_Perplexity_Chat.Input a = new Web_Search_w_Perplexity_Chat.Input();
        a.systemPrompt = 'sys';
        try {
            Web_Search_w_Perplexity_Chat.run(new List<Web_Search_w_Perplexity_Chat.Input>{ a });
            System.assert(false, 'Expected error for missing user prompt');
        } catch (IllegalArgumentException e) {
            System.assert(e.getMessage().toLowerCase().contains('user prompt is required'));
        }

        // Missing systemPrompt
        Web_Search_w_Perplexity_Chat.Input b = new Web_Search_w_Perplexity_Chat.Input();
        b.userPrompt = 'user';
        try {
            Web_Search_w_Perplexity_Chat.run(new List<Web_Search_w_Perplexity_Chat.Input>{ b });
            System.assert(false, 'Expected error for missing system prompt');
        } catch (IllegalArgumentException e) {
            System.assert(e.getMessage().toLowerCase().contains('system prompt is required'));
        }
    }
}