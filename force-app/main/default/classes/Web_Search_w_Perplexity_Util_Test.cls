@IsTest
private class Web_Search_w_Perplexity_Util_Test {

    /* ===========
       Helpers
       =========== */

    private static HttpRequest makeReq() {
        HttpRequest req = new HttpRequest();
        req.setEndpoint('https://example.com/test'); // mocked
        req.setMethod('GET');
        return req;
    }

    // Sequence-based HttpCalloutMock.
    // Pass a list of "steps":
    //  - positive HTTP status code (e.g., 200, 429, 500) → return that code
    //  - 0 → throw a transport exception
    private class SequenceMock implements HttpCalloutMock {
        private List<Integer> steps;

        SequenceMock(List<Integer> s) {
            // Copy to avoid accidental external mutation
            this.steps = (s == null) ? new List<Integer>() : new List<Integer>(s);
        }

        public HttpResponse respond(HttpRequest req) {
            if (steps.isEmpty()) {
                HttpResponse ok = new HttpResponse();
                ok.setStatusCode(200);
                ok.setStatus('200 OK');
                ok.setBody('{"ok":true}');
                return ok;
            }
            Integer step = steps[0];
            steps.remove(0);

            if (step == 0) {
                // Simulate a transport/low-level callout failure
                throw new CalloutException('Simulated transport exception');
            }

            HttpResponse res = new HttpResponse();
            res.setStatusCode(step);
            res.setStatus(String.valueOf(step) + ' STATUS');
            res.setBody('{"code":' + String.valueOf(step) + '}');
            return res;
        }
    }

    /* ===========
       Unit tests
       =========== */

    @IsTest
    static void testIsBlankAndTrimLower() {
        System.assertEquals(true,  Web_Search_w_Perplexity_Util.isBlank(null));
        System.assertEquals(true,  Web_Search_w_Perplexity_Util.isBlank('   '));
        System.assertEquals(false, Web_Search_w_Perplexity_Util.isBlank('x'));

        System.assertEquals('abc', Web_Search_w_Perplexity_Util.trimLower('  AbC  '));
        System.assertEquals(null,  Web_Search_w_Perplexity_Util.trimLower(null));
    }

    @IsTest
    static void testNormalizeModelVariants() {
        System.assertEquals('sonar', Web_Search_w_Perplexity_Util.normalizeModel(null));
        System.assertEquals('sonar', Web_Search_w_Perplexity_Util.normalizeModel(''));
        System.assertEquals('sonar', Web_Search_w_Perplexity_Util.normalizeModel('  '));
        System.assertEquals('sonar', Web_Search_w_Perplexity_Util.normalizeModel('SONAR'));
        System.assertEquals('sonar-pro', Web_Search_w_Perplexity_Util.normalizeModel(' Sonar PRO '));
        System.assertEquals('sonar-reasoning', Web_Search_w_Perplexity_Util.normalizeModel('sonar_reasoning'));
        System.assertEquals('sonar-reasoning-pro', Web_Search_w_Perplexity_Util.normalizeModel('sonar reasoning pro'));
        System.assertEquals('sonar-reasoning', Web_Search_w_Perplexity_Util.normalizeModel('reason'));
        System.assertEquals('sonar-pro', Web_Search_w_Perplexity_Util.normalizeModel('pro'));
    }

    @IsTest
    static void testNormalizeSearchModeVariants() {
        System.assertEquals('web', Web_Search_w_Perplexity_Util.normalizeSearchMode(null));
        System.assertEquals('web', Web_Search_w_Perplexity_Util.normalizeSearchMode('  '));
        System.assertEquals('web', Web_Search_w_Perplexity_Util.normalizeSearchMode('WeB'));
        System.assertEquals('academic', Web_Search_w_Perplexity_Util.normalizeSearchMode('  Academic '));
        System.assertEquals('sec', Web_Search_w_Perplexity_Util.normalizeSearchMode('SEC'));
        System.assertEquals('sec', Web_Search_w_Perplexity_Util.normalizeSearchMode('secfilings'));
        System.assertEquals('web', Web_Search_w_Perplexity_Util.normalizeSearchMode('unknown'));
    }

    @IsTest
    static void testNormalizeContextSize() {
        System.assertEquals(null, Web_Search_w_Perplexity_Util.normalizeContextSize(null));
        System.assertEquals('low', Web_Search_w_Perplexity_Util.normalizeContextSize('low'));
        System.assertEquals('medium', Web_Search_w_Perplexity_Util.normalizeContextSize(' Med '));
        System.assertEquals('high', Web_Search_w_Perplexity_Util.normalizeContextSize('  hi  '));
        System.assertEquals(null, Web_Search_w_Perplexity_Util.normalizeContextSize('gigantic'));
    }

    @IsTest
    static void testParseDomainFilterAllowAndDedupe() {
        String raw = ' https://www.Example.com/path , example.com/,EXAMPLE.com  , docs.salesforce.com ';
        List<String> parsed = Web_Search_w_Perplexity_Util.parseDomainFilter(raw);
        System.assertEquals(2, parsed.size());
        System.assertEquals('example.com', parsed[0]);
        System.assertEquals('docs.salesforce.com', parsed[1]);
    }

    @IsTest
    static void testParseDomainFilterDeny() {
        String raw = '-pinterest.com, -GettyImages.com';
        List<String> parsed = Web_Search_w_Perplexity_Util.parseDomainFilter(raw);
        System.assertEquals(2, parsed.size());
        System.assertEquals('-pinterest.com', parsed[0]);
        System.assertEquals('-gettyimages.com', parsed[1]);
    }

    @IsTest
    static void testParseDomainFilterMixThrows() {
        try {
            Web_Search_w_Perplexity_Util.parseDomainFilter('nasa.gov, -wikipedia.org');
            System.assert(false, 'Expected IllegalArgumentException for mixed allow/deny');
        } catch (IllegalArgumentException e) {
            System.assert(e.getMessage().contains('cannot mix allowlist and denylist'));
        }
    }

    @IsTest
    static void testParseDomainFilterOverLimitThrows() {
        List<String> ds = new List<String>();
        for (Integer i = 0; i < 21; i++) ds.add('d' + i + '.com');
        try {
            Web_Search_w_Perplexity_Util.parseDomainFilter(String.join(ds, ','));
            System.assert(false, 'Expected IllegalArgumentException for >20 entries');
        } catch (IllegalArgumentException e) {
            System.assert(e.getMessage().contains('at most 20'));
        }
    }

    @IsTest
    static void testNormalizeDateIsoAndUs() {
        System.assertEquals('3/1/2025', Web_Search_w_Perplexity_Util.normalizeDate('2025-03-01'));
        System.assertEquals('3/1/2025', Web_Search_w_Perplexity_Util.normalizeDate('03/01/2025'));
        System.assertEquals('3/1/2025', Web_Search_w_Perplexity_Util.normalizeDate('3/1/2025'));
    }

    @IsTest
    static void testNormalizeDateInvalidThrows() {
        try {
            Web_Search_w_Perplexity_Util.normalizeDate('2025/03/01'); // wrong format
            System.assert(false, 'Expected IllegalArgumentException for invalid date format');
        } catch (IllegalArgumentException e) {
            System.assert(e.getMessage().contains('Invalid date'));
        }
    }

    @IsTest
    static void testNormalizeRecency() {
        System.assertEquals(null, Web_Search_w_Perplexity_Util.normalizeRecency(null));
        System.assertEquals('day',   Web_Search_w_Perplexity_Util.normalizeRecency('d'));
        System.assertEquals('week',  Web_Search_w_Perplexity_Util.normalizeRecency('WEEK'));
        System.assertEquals('month', Web_Search_w_Perplexity_Util.normalizeRecency('mo'));
        System.assertEquals('year',  Web_Search_w_Perplexity_Util.normalizeRecency('y'));
        System.assertEquals(null,    Web_Search_w_Perplexity_Util.normalizeRecency('decade'));
    }

    @IsTest
    static void testClampInt() {
        System.assertEquals(5,  Web_Search_w_Perplexity_Util.clampInt(5, 1, 10, 7));
        System.assertEquals(1,  Web_Search_w_Perplexity_Util.clampInt(-3, 1, 10, 7));
        System.assertEquals(10, Web_Search_w_Perplexity_Util.clampInt(99, 1, 10, 7));
        System.assertEquals(7,  Web_Search_w_Perplexity_Util.clampInt(null, 1, 10, 7));
        System.assertEquals(null, Web_Search_w_Perplexity_Util.clampInt(null, 1, 10, null));
    }

    @IsTest
    static void testNormalizeCountryValidInvalid() {
        System.assertEquals('US', Web_Search_w_Perplexity_Util.normalizeCountry('us'));
        System.assertEquals('GB', Web_Search_w_Perplexity_Util.normalizeCountry('GB'));
        try {
            Web_Search_w_Perplexity_Util.normalizeCountry('USA');
            System.assert(false, 'Expected IllegalArgumentException for invalid ISO-2');
        } catch (IllegalArgumentException e) {
            System.assert(e.getMessage().contains('ISO 3166-1 alpha-2'));
        }
    }

    @IsTest
    static void testDeepMergeFlowWinsAndFilters() {
        Map<String,Object> base = new Map<String,Object>{
            'model' => 'sonar',
            'a' => 'baseA',
            'nested' => new Map<String,Object>{ 'child' => 'baseChild', 'keep' => 'k' }
        };
        String advanced =
            '{"model":"hacked","a":"advA","b":"advB","blocked":"x","nested":{"child":"advChild","new":"n"},"unknown":"?","query":"nope"}';
        Set<String> allow = new Set<String>{ 'a','b','nested' };
        Set<String> block = new Set<String>{ 'model','query','blocked' };

        Map<String,Object> merged = Web_Search_w_Perplexity_Util.deepMerge(base, advanced, allow, block);

        System.assertEquals('sonar', (String)merged.get('model')); // blocked
        System.assertEquals('baseA', (String)merged.get('a'));     // Flow wins
        System.assertEquals('advB',  (String)merged.get('b'));     // allowed
        System.assertEquals(false,   merged.containsKey('blocked'));
        System.assertEquals(false,   merged.containsKey('unknown'));
        System.assertEquals(false,   merged.containsKey('query'));

        Map<String,Object> nested = (Map<String,Object>) merged.get('nested');
        System.assertEquals('baseChild', (String) nested.get('child'));
        System.assertEquals('k',         (String) nested.get('keep'));
        System.assertEquals('n',         (String) nested.get('new'));
    }

    @IsTest
    static void testSendWithRetries_successFirstTry() {
        Test.setMock(HttpCalloutMock.class, new SequenceMock(null)); // default 200
        HttpRequest req = makeReq();
        Test.startTest();
        HttpResponse res = Web_Search_w_Perplexity_Util.sendWithRetries(req, 3);
        Test.stopTest();
        System.assertEquals(200, res.getStatusCode());
    }

    @IsTest
    static void testSendWithRetries_retryThenSuccess() {
        Test.setMock(HttpCalloutMock.class, new SequenceMock(new List<Integer>{ 500, 200 }));
        HttpRequest req = makeReq();
        Test.startTest();
        HttpResponse res = Web_Search_w_Perplexity_Util.sendWithRetries(req, 3);
        Test.stopTest();
        System.assertEquals(200, res.getStatusCode());
    }

    @IsTest
    static void testSendWithRetries_retryExhaustReturnsLastResponse() {
        Test.setMock(HttpCalloutMock.class, new SequenceMock(new List<Integer>{ 500, 500 }));
        HttpRequest req = makeReq();
        Test.startTest();
        HttpResponse res = Web_Search_w_Perplexity_Util.sendWithRetries(req, 2);
        Test.stopTest();
        System.assertEquals(500, res.getStatusCode());
    }

    @IsTest
    static void testSendWithRetries_exceptionThenSuccess() {
        Test.setMock(HttpCalloutMock.class, new SequenceMock(new List<Integer>{ 0, 200 })); // 0 => throw
        HttpRequest req = makeReq();
        Test.startTest();
        HttpResponse res = Web_Search_w_Perplexity_Util.sendWithRetries(req, 3);
        Test.stopTest();
        System.assertEquals(200, res.getStatusCode());
    }
}