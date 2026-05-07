public without sharing class Web_Search_w_Perplexity_Search {

    /* ---------- CONSTANTS ---------- */
    private static final String NC_SEARCH = 'callout:Perplexity_API/search';
    private static final Integer DEFAULT_TIMEOUT_MS = 120000;

    /* ---------- INPUT ---------- */
    public class Input {
        @InvocableVariable(label='Query' required=true
            description='The search string. Provide multiple lines for multi-query; each non-empty line becomes a separate query element.')
        public String query;

        @InvocableVariable(label='Domain Filter (allowlist)' required=false
            description='Comma or newline-separated domains/URLs (≤20). Limits results to these domains. Example: science.org, pnas.org, cell.com. Note: /search supports allowlist only (no leading "-").')
        public String searchDomainFilter;

        @InvocableVariable(label='Max Results' required=false
            description='1–20. Default is 10 if omitted. Values outside range are clamped.')
        public Integer maxResults;

        @InvocableVariable(label='Max Tokens per Page' required=false
            description='Controls extraction depth per result page; default 1024 if omitted.')
        public Integer maxTokensPerPage;

        @InvocableVariable(label='Country (ISO-2)' required=false
            description='Geographic targeting (e.g., US, GB, DE). We uppercase and validate.')
        public String country;

        @InvocableVariable(label='Timeout (ms)' required=false
            description='HTTP timeout. Clamped to Salesforce max 120000. Default 120000 if omitted.')
        public Integer timeoutMs;
    }

    /* ---------- OUTPUT ---------- */
    public class Output {
        @InvocableVariable(label='Full JSON Response')
        public String fullJsonResponse;
    }

    /* ---------- MAIN ACTION ---------- */
    @InvocableMethod(
        label='Perplexity: Search'
        description='POST /search with documented parameters: query, search_domain_filter, max_results, max_tokens_per_page, country. Returns raw JSON (results with title, url, snippet, date, last_updated).'
    )
    public static List<Output> run(List<Input> inputs) {
        if (inputs == null || inputs.isEmpty()) {
            throw new IllegalArgumentException('No input provided.');
        }
        Input i = inputs[0];

        // Parse query: newline-separated → array; else single string
        Object queryPayload;
        if (!Web_Search_w_Perplexity_Util.isBlank(i.query) && i.query.contains('\n')) {
            List<String> qs = new List<String>();
            for (String line : i.query.split('\\n')) {
                String s = (line == null) ? null : line.trim();
                if (!Web_Search_w_Perplexity_Util.isBlank(s)) qs.add(s);
            }
            if (qs.isEmpty()) throw new IllegalArgumentException('Query cannot be blank.');
            queryPayload = qs;
        } else {
            if (Web_Search_w_Perplexity_Util.isBlank(i.query)) throw new IllegalArgumentException('Query cannot be blank.');
            queryPayload = i.query.trim();
        }

        // Documented parameters only
        Integer maxResults = Web_Search_w_Perplexity_Util.clampInt(i.maxResults, 1, 20, null);
        Integer mtpp       = (i.maxTokensPerPage == null) ? null
                          : Web_Search_w_Perplexity_Util.clampInt(i.maxTokensPerPage, 1, 100000, i.maxTokensPerPage);
        String  country    = Web_Search_w_Perplexity_Util.normalizeCountry(i.country);

        // Domain allowlist (no deny entries supported by /search)
        List<String> domains = Web_Search_w_Perplexity_Util.parseDomainFilter(i.searchDomainFilter);
        if (domains != null) {
            for (String d : domains) {
                if (d != null && d.startsWith('-')) {
                    throw new IllegalArgumentException(
                        'search_domain_filter for /search only supports an allowlist; remove the leading "-" from "' + d + '".'
                    );
                }
            }
        }

        // Build request body
        Map<String,Object> body = new Map<String,Object>{ 'query' => queryPayload };
        if (maxResults != null) body.put('max_results', maxResults);
        if (mtpp != null)       body.put('max_tokens_per_page', mtpp);
        if (country != null)    body.put('country', country);
        if (domains != null && !domains.isEmpty()) body.put('search_domain_filter', domains);

        // HTTP call
        HttpRequest req = new HttpRequest();
        req.setEndpoint(NC_SEARCH);
        req.setMethod('POST');
        req.setHeader('Content-Type','application/json');
        req.setHeader('User-Agent', 'SFDC-Perplexity-Integration/1.0');
        req.setHeader('X-Request-ID', String.valueOf(Crypto.getRandomLong()));
        req.setTimeout(Web_Search_w_Perplexity_Util.clampInt(i.timeoutMs, 1000, DEFAULT_TIMEOUT_MS, DEFAULT_TIMEOUT_MS));
        req.setBody(JSON.serialize(body));

        HttpResponse res = Web_Search_w_Perplexity_Util.sendWithRetries(req, 3);

        Output out = new Output();
        out.fullJsonResponse = (res == null) ? null : res.getBody();
        return new List<Output>{ out };
    }
}