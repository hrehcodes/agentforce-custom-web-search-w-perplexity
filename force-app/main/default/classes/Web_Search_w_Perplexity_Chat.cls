public with sharing class Web_Search_w_Perplexity_Chat {

    /* ---------- INPUT ---------- */
    public class Input {
        @InvocableVariable(label='User Prompt' required=true
            description='User message sent to Sonar. Example: Summarize the latest earnings call for Salesforce and cite sources.')
        public String userPrompt;

        @InvocableVariable(label='System Prompt' required=true
            description='System instruction to steer the assistant. Example: You are a precise research assistant. Prefer primary sources.')
        public String systemPrompt;

        @InvocableVariable(label='Model' required=false
            description='Allowed: sonar (default), sonar-pro, sonar-reasoning, sonar-reasoning-pro. Input tolerant to case/spacing/underscores (e.g., " Sonar PRO " → sonar-pro).')
        public String model;

        @InvocableVariable(label='Search Mode' required=false
            description='Allowed: web (default), academic, sec. Input tolerant to case/spacing (e.g., "  SEC " → sec).')
        public String searchMode;

        @InvocableVariable(label='Search Context Size' required=false
            description='How much web context to retrieve: low | medium | high. Omit to let API default. Input tolerant (e.g., " hi " → high).')
        public String searchContextSize;

        @InvocableVariable(label='Domain Filter (allow OR deny list)' required=false
            description='Comma or newline-separated domains/URLs (≤20). Example allowlist: nasa.gov, wikipedia.org. Example denylist: -pinterest.com (leading "-" means deny). We trim/dedupe, strip http(s):// and www., and disallow mixing allow+deny in one request.')
        public String searchDomainFilter;

        @InvocableVariable(label='Recency Filter' required=false
            description='day | week | month | year. Not allowed together with explicit date ranges.')
        public String searchRecencyFilter;

        @InvocableVariable(label='Published After (M/D/YYYY or YYYY-MM-DD)' required=false
            description='Lower bound on publication date. Example: 2025-03-01 → normalized to 3/1/2025.')
        public String searchAfterDate;

        @InvocableVariable(label='Published Before (M/D/YYYY or YYYY-MM-DD)' required=false
            description='Upper bound on publication date.')
        public String searchBeforeDate;

        @InvocableVariable(label='Last Updated After (M/D/YYYY or YYYY-MM-DD)' required=false
            description='Lower bound on last-updated date.')
        public String lastUpdatedAfter;

        @InvocableVariable(label='Last Updated Before (M/D/YYYY or YYYY-MM-DD)' required=false
            description='Upper bound on last-updated date.')
        public String lastUpdatedBefore;

        @InvocableVariable(label='Enable Search Classifier?' required=false
            description='true/false. If true, Sonar decides if web search is needed.')
        public Boolean enableSearchClassifier;

        @InvocableVariable(label='Disable Web Search?' required=false
            description='true/false. If true, Sonar does not call the web at all.')
        public Boolean disableSearch;

        /* ---- New expert tuning options (now first-class inputs) ---- */

        @InvocableVariable(label='Max Tokens' required=false
            description='Upper bound on response tokens. Positive integer. Example: 900.')
        public Integer maxTokens;

        @InvocableVariable(label='Temperature' required=false
            description='Controls randomness (0 to <2). Lower = more focused; higher = more creative. Example: 0.2.')
        public Decimal temperature;

        @InvocableVariable(label='Top P' required=false
            description='Nucleus sampling 0–1. Example: 0.9.')
        public Decimal topP;

        @InvocableVariable(label='Top K' required=false
            description='Limits candidate tokens at each step (non-negative integer). Example: 50.')
        public Integer topK;

        @InvocableVariable(label='Presence Penalty' required=false
            description='Discourage repetition by penalizing tokens already present. Range often -2..2. Example: 0.0.')
        public Decimal presencePenalty;

        @InvocableVariable(label='Frequency Penalty' required=false
            description='Discourage frequent tokens. Range often -2..2. Example: 0.0.')
        public Decimal frequencyPenalty;

        @InvocableVariable(label='Response Format Type' required=false
            description='Set to "json_object" to request structured JSON output; leave blank for normal text.')
        public String responseFormatType;

        @InvocableVariable(label='User Location: Country (ISO-2)' required=false
            description='For geo-relevance under web_search_options.user_location. Example: US, GB, DE.')
        public String userLocationCountry;

        @InvocableVariable(label='User Location: Region/State' required=false
            description='Optional region/state for user_location. Example: California.')
        public String userLocationRegion;

        @InvocableVariable(label='User Location: City' required=false
            description='Optional city for user_location. Example: San Francisco.')
        public String userLocationCity;

        @InvocableVariable(label='Return Related Questions?' required=false
            description='true/false. If true, model may include related questions in response.')
        public Boolean returnRelatedQuestions;

        @InvocableVariable(label='Return Images?' required=false
            description='true/false. If true, Sonar may include images when relevant.')
        public Boolean returnImages;

        @InvocableVariable(label='Return Videos?' required=false
            description='true/false. If true, Sonar may include videos when relevant.')
        public Boolean returnVideos;

        @InvocableVariable(label='Image Domain Filter' required=false
            description='Optional comma/newline list of domains for images (allow OR deny with leading "-"). Same rules as Domain Filter (≤20, no mixing allow+deny).')
        public String imageDomainFilter;

        @InvocableVariable(label='Image Format Filter' required=false
            description='Optional comma/newline list of image formats to allow (e.g., jpg, jpeg, png, webp, gif).')
        public String imageFormatFilter;

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
        label='Perplexity: Chat Completions'
        description='POST /chat/completions with robust normalization & validation. Returns raw JSON (choices, usage, citations, etc.).'
    )
    public static List<Output> run(List<Input> inputs) {
        if (inputs == null || inputs.isEmpty()) {
            throw new IllegalArgumentException('No input provided.');
        }
        Input i = inputs[0];

        if (Web_Search_w_Perplexity_Util.isBlank(i.userPrompt))  throw new IllegalArgumentException('User Prompt is required.');
        if (Web_Search_w_Perplexity_Util.isBlank(i.systemPrompt)) throw new IllegalArgumentException('System Prompt is required.');

        // Normalize model & modes
        String model = Web_Search_w_Perplexity_Util.normalizeModel(i.model);
        if (!Web_Search_w_Perplexity_Util.CHAT_MODELS.contains(model)) {
            throw new IllegalArgumentException('Unsupported model "' + i.model + '". Allowed: ' + String.join(new List<String>(Web_Search_w_Perplexity_Util.CHAT_MODELS), ', '));
        }
        String searchMode = Web_Search_w_Perplexity_Util.normalizeSearchMode(i.searchMode);
        String ctxSize    = Web_Search_w_Perplexity_Util.normalizeContextSize(i.searchContextSize);

        // Dates & recency
        String recency  = Web_Search_w_Perplexity_Util.normalizeRecency(i.searchRecencyFilter);
        String pubAfter = Web_Search_w_Perplexity_Util.normalizeDate(i.searchAfterDate);
        String pubBefore= Web_Search_w_Perplexity_Util.normalizeDate(i.searchBeforeDate);
        String updAfter = Web_Search_w_Perplexity_Util.normalizeDate(i.lastUpdatedAfter);
        String updBefore= Web_Search_w_Perplexity_Util.normalizeDate(i.lastUpdatedBefore);
        if (recency != null && (pubAfter != null || pubBefore != null || updAfter != null || updBefore != null)) {
            throw new IllegalArgumentException('Recency filter cannot be combined with explicit date filters.');
        }

        // Domain filters
        List<String> domains      = Web_Search_w_Perplexity_Util.parseDomainFilter(i.searchDomainFilter);
        List<String> imageDomains = Web_Search_w_Perplexity_Util.parseDomainFilter(i.imageDomainFilter);
        List<String> imageFormats = parseImageFormats(i.imageFormatFilter); // validates/normalizes

        // Build messages
        List<Object> messages = new List<Object>{
            new Map<String,Object>{ 'role' => 'system', 'content' => i.systemPrompt },
            new Map<String,Object>{ 'role' => 'user',   'content' => i.userPrompt }
        };

        // Base body
        Map<String,Object> body = new Map<String,Object>{
            'model'       => model,
            'messages'    => messages,
            'search_mode' => searchMode
        };

        // Search controls & filters
        if (i.disableSearch == true) body.put('disable_search', true);
        if (i.enableSearchClassifier == true) body.put('enable_search_classifier', true);
        if (domains != null) body.put('search_domain_filter', domains);
        if (recency != null) body.put('search_recency_filter', recency);
        if (pubAfter != null) body.put('search_after_date_filter', pubAfter);
        if (pubBefore!= null) body.put('search_before_date_filter', pubBefore);
        if (updAfter != null) body.put('last_updated_after_filter', updAfter);
        if (updBefore!= null) body.put('last_updated_before_filter', updBefore);

        // Tuning params
        if (i.maxTokens != null && i.maxTokens > 0) body.put('max_tokens', Web_Search_w_Perplexity_Util.clampInt(i.maxTokens, 1, 128000, i.maxTokens));
        if (i.temperature != null) body.put('temperature', clampDecimal(i.temperature, 0, 1.9999));
        if (i.topP != null)        body.put('top_p', clampDecimal(i.topP, 0, 1));
        if (i.topK != null && i.topK >= 0) body.put('top_k', i.topK);
        if (i.presencePenalty != null)  body.put('presence_penalty', clampDecimal(i.presencePenalty, -2, 2));
        if (i.frequencyPenalty != null) body.put('frequency_penalty', clampDecimal(i.frequencyPenalty, -2, 2));

        // Response format
        String rf = normalizeResponseFormat(i.responseFormatType);
        if (rf != null) {
            body.put('response_format', new Map<String,Object>{ 'type' => rf });
        }

        // web_search_options (context size + user location)
        Map<String,Object> wsOpts = new Map<String,Object>();
        if (ctxSize != null) wsOpts.put('search_context_size', ctxSize);

        Map<String,Object> userLoc = buildUserLocation(i.userLocationCountry, i.userLocationRegion, i.userLocationCity);
        if (userLoc != null && !userLoc.isEmpty()) wsOpts.put('user_location', userLoc);

        if (!wsOpts.isEmpty()) body.put('web_search_options', wsOpts);

        // media_response overrides (images/videos)
        if ((i.returnImages == true) || (i.returnVideos == true)) {
            Map<String,Object> overrides = new Map<String,Object>();
            if (i.returnImages == true) overrides.put('return_images', true);
            if (i.returnVideos == true) overrides.put('return_videos', true);
            body.put('media_response', new Map<String,Object>{ 'overrides' => overrides });
        }

        // Image filters
        if (imageDomains != null) body.put('image_domain_filter', imageDomains);
        if (imageFormats  != null && !imageFormats.isEmpty()) body.put('image_format_filter', imageFormats);

        // Related questions
        if (i.returnRelatedQuestions == true) body.put('return_related_questions', true);

        // HTTP call
        HttpRequest req = new HttpRequest();
        req.setEndpoint('callout:Perplexity_API/chat/completions');
        req.setMethod('POST');
        req.setHeader('Content-Type','application/json');
        req.setTimeout(Web_Search_w_Perplexity_Util.clampInt(i.timeoutMs, 1000, 120000, 120000));
        req.setBody(JSON.serialize(body));

        HttpResponse res = Web_Search_w_Perplexity_Util.sendWithRetries(req, 3);

        Output out = new Output();
        out.fullJsonResponse = Web_Search_w_Perplexity_Util.toAgentSafeBody(res);
        return new List<Output>{ out };
    }

    /* ---------- Private helpers (class-local) ---------- */

    private static Decimal clampDecimal(Decimal v, Decimal minV, Decimal maxV) {
        if (v == null) return null;
        Decimal x = v;
        if (minV != null && x < minV) x = minV;
        if (maxV != null && x > maxV) x = maxV;
        return x;
    }

    private static String normalizeResponseFormat(String raw) {
        if (Web_Search_w_Perplexity_Util.isBlank(raw)) return null;
        String s = raw.trim().toLowerCase().replace(' ', '_');
        // tolerate common variants
        if (s == 'json' || s == 'json_object' || s == 'json-object') return 'json_object';
        // anything else → ignore (no error; keep robust)
        return null;
    }

    private static Map<String,Object> buildUserLocation(String countryRaw, String region, String city) {
        Map<String,Object> m = new Map<String,Object>();
        String country = Web_Search_w_Perplexity_Util.normalizeCountry(countryRaw);
        if (country != null) m.put('country', country);
        if (!Web_Search_w_Perplexity_Util.isBlank(region)) m.put('region', region.trim());
        if (!Web_Search_w_Perplexity_Util.isBlank(city))   m.put('city',   city.trim());
        return m.isEmpty() ? null : m;
    }

    private static List<String> parseImageFormats(String raw) {
        if (Web_Search_w_Perplexity_Util.isBlank(raw)) return null;
        Set<String> allowed = new Set<String>{ 'jpg','jpeg','png','webp','gif' };
        Set<String> outSet = new Set<String>();
        for (String token : raw.split('[,\\n]+')) {
            String f = (token == null) ? null : token.trim().toLowerCase();
            if (Web_Search_w_Perplexity_Util.isBlank(f)) continue;
            // normalize jpeg/jpg
            if (f == 'jpeg' || f == 'jpg') f = (f == 'jpg') ? 'jpg' : 'jpeg';
            if (!allowed.contains(f)) {
                // Be forgiving: skip unknowns rather than erroring out
                continue;
            }
            outSet.add(f);
        }
        return outSet.isEmpty() ? null : new List<String>(outSet);
    }
}