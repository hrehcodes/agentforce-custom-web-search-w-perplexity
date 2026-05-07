public without sharing class Web_Search_w_Perplexity_Util {

    /* =========================
       Basic helpers & constants
       ========================= */
    public static Boolean isBlank(String s) {
        return s == null || s.trim().length() == 0;
    }

    // Public allow-lists used by Chat normalization/validation
    public static final Set<String> CHAT_MODELS = new Set<String>{
        'sonar','sonar-pro','sonar-reasoning','sonar-reasoning-pro'
    };
    public static final Set<String> SEARCH_CONTEXT = new Set<String>{ 'low','medium','high' };
    public static final Set<String> SEARCH_MODES   = new Set<String>{ 'web','academic','sec' };
    public static final Set<String> RECENCY        = new Set<String>{ 'day','week','month','year' };

    public static String trimLower(String s) {
        return (s == null) ? null : s.trim().toLowerCase();
    }

    /* =========================
       Normalizers (Chat inputs)
       ========================= */
    public static String normalizeModel(String raw) {
        String s = trimLower(raw);
        if (isBlank(s)) return 'sonar';
        s = s.replace(' ', '-').replace('_','-');
        if (s == 'sonar-pro' || s == 'sonar' || s == 'sonar-reasoning' || s == 'sonar-reasoning-pro') return s;
        // tolerant heuristics
        if (s.contains('reason') && s.contains('pro')) return 'sonar-reasoning-pro';
        if (s.contains('reason')) return 'sonar-reasoning';
        if (s.contains('pro'))    return 'sonar-pro';
        return 'sonar';
    }

    public static String normalizeSearchMode(String raw) {
        String s = trimLower(raw);
        if (isBlank(s)) return 'web';
        s = s.replace(' ', '');
        if (s.startsWith('acad')) return 'academic';
        if (s == 'sec' || s == 'secfilings') return 'sec';
        return SEARCH_MODES.contains(s) ? s : 'web';
    }

    public static String normalizeContextSize(String raw) {
        String s = trimLower(raw);
        if (isBlank(s)) return null; // omit → Perplexity default
        if (s.startsWith('hi'))  return 'high';
        if (s.startsWith('med')) return 'medium';
        if (s.startsWith('lo'))  return 'low';
        return SEARCH_CONTEXT.contains(s) ? s : null;
    }

    /* ==========================================
       Domain filter parsing (allow or deny list)
       - Accepts comma or newline separated tokens
       - Dedupe case-insensitively
       - Strips protocol, www, and any path/query
       - Max 20 items
       - Throws if both allow and deny are mixed
       ========================================== */
    public static List<String> parseDomainFilter(String raw) {
        if (isBlank(raw)) return null;

        Set<String> seen = new Set<String>();
        List<String> out = new List<String>();

        for (String token : raw.split('[,\\n]+')) { // comma OR newline
            String d = (token == null) ? null : token.trim().toLowerCase();
            if (isBlank(d)) continue;

            // strip protocol and www
            if (d.startsWith('http://'))  d = d.substring(7);
            if (d.startsWith('https://')) d = d.substring(8);
            if (d.startsWith('www.'))     d = d.substring(4);

            // drop any path/query/fragment after the hostname
            Integer slashIdx = d.indexOf('/');
            if (slashIdx != -1) d = d.substring(0, slashIdx);

            // trailing slash guard
            if (d.endsWith('/')) d = d.substring(0, d.length() - 1);

            if (!seen.contains(d)) {
                seen.add(d);
                out.add(d);
            }
            if (out.size() > 20) break;
        }
        if (out.isEmpty()) return null;

        // ensure not mixing allow and deny
        Boolean hasAllow = false, hasDeny = false;
        for (String d : out) {
            if (d.startsWith('-')) hasDeny = true; else hasAllow = true;
        }
        if (hasAllow && hasDeny) {
            throw new IllegalArgumentException('search_domain_filter cannot mix allowlist and denylist in the same request.');
        }
        if (out.size() > 20) {
            throw new IllegalArgumentException('search_domain_filter supports at most 20 entries.');
        }
        return out;
    }

    /* =========================
       Regex & date normalization
       ========================= */
    private static Boolean regexMatch(String input, String regex) {
        if (input == null) return false;
        Pattern p = Pattern.compile(regex);
        Matcher m = p.matcher(input);
        return m.matches();
    }

    // Accept YYYY-MM-DD or M/D/YYYY; output normalized M/D/YYYY
    public static String normalizeDate(String raw) {
        if (isBlank(raw)) return null;
        String s = raw.trim();

        // ISO yyyy-mm-dd
        if (regexMatch(s, '^\\d{4}-\\d{2}-\\d{2}$')) {
            Date d = Date.valueOf(s);
            return d.month() + '/' + d.day() + '/' + d.year();
        }
        // m/d/yyyy (1 or 2 digits for m/d)
        if (regexMatch(s, '^(0?[1-9]|1[0-2])/(0?[1-9]|[12][0-9]|3[01])/[0-9]{4}$')) {
            List<String> parts = s.split('/');
            Integer m = Integer.valueOf(parts[0]);
            Integer d = Integer.valueOf(parts[1]);
            Integer y = Integer.valueOf(parts[2]);
            return m + '/' + d + '/' + y;
        }
        throw new IllegalArgumentException('Invalid date "' + raw + '". Use YYYY-MM-DD or M/D/YYYY.');
    }

    // Strict-ish recency normalization, avoids accidental matches like "decade"
    public static String normalizeRecency(String raw) {
        String s = trimLower(raw);
        if (isBlank(s)) return null;

        if (regexMatch(s, '^(d|day|days)$'))            return 'day';
        if (regexMatch(s, '^(w|week|weeks)$'))          return 'week';
        if (regexMatch(s, '^(mo|month|months)$'))       return 'month';
        if (regexMatch(s, '^(y|year|years)$'))          return 'year';

        // exact allow-list
        return RECENCY.contains(s) ? s : null;
    }

    /* =========================
       Scalars & country checking
       ========================= */
    public static Integer clampInt(Integer v, Integer minV, Integer maxV, Integer defV) {
        if (v == null) return defV;
        Integer x = v;
        if (minV != null && x < minV) x = minV;
        if (maxV != null && x > maxV) x = maxV;
        return x;
    }

    public static String normalizeCountry(String raw) {
        if (isBlank(raw)) return null;
        String s = raw.trim().toUpperCase();
        if (!regexMatch(s, '^[A-Z]{2}$')) {
            throw new IllegalArgumentException('Country must be ISO 3166-1 alpha-2 (e.g., US, GB, DE).');
        }
        return s;
    }

    /* =========================
       Image format filter helper
       ========================= */
    public static List<String> parseImageFormats(String raw) {
        if (isBlank(raw)) return null;
        Set<String> allowed = new Set<String>{ 'jpg','jpeg','png','webp','gif' };
        Set<String> outSet  = new Set<String>();
        for (String token : raw.split('[,\\n]+')) {
            String f = (token == null) ? null : token.trim().toLowerCase();
            if (isBlank(f)) continue;

            // normalize jpeg/jpg to canonical tokens
            if (f == 'jpeg' || f == 'jpg') {
                f = (f == 'jpg') ? 'jpg' : 'jpeg';
            }
            if (!allowed.contains(f)) {
                // be forgiving: skip unknowns rather than error
                continue;
            }
            outSet.add(f);
        }
        return outSet.isEmpty() ? null : new List<String>(outSet);
    }

    /* =========================
       Deep merge (kept for reuse)
       Flow-base ← advanced JSON
       ========================= */
    public static Map<String,Object> deepMerge(Map<String,Object> base, String advancedJson, Set<String> allowTop, Set<String> blockTop) {
        if (isBlank(advancedJson)) return base;

        Object parsed;
        try {
            parsed = JSON.deserializeUntyped(advancedJson);
        } catch (Exception e) {
            throw new IllegalArgumentException('advancedParamsJson is not valid JSON: ' + e.getMessage());
        }
        if (!(parsed instanceof Map<String,Object>)) {
            throw new IllegalArgumentException('advancedParamsJson must be a JSON object.');
        }
        Map<String,Object> adv = (Map<String,Object>) parsed;

        // top-level filter
        for (String k : new List<String>(adv.keySet())) {
            if (blockTop != null && blockTop.contains(k)) adv.remove(k);
            else if (allowTop != null && !allowTop.contains(k)) adv.remove(k);
        }
        return mergeRec(base, adv); // Flow values win
    }

    private static Map<String,Object> mergeRec(Map<String,Object> base, Map<String,Object> add) {
        if (add == null) return base;
        for (String k : add.keySet()) {
            if (!base.containsKey(k) || base.get(k) == null) {
                base.put(k, add.get(k));
            } else {
                Object b = base.get(k), a = add.get(k);
                if (b instanceof Map<String,Object> && a instanceof Map<String,Object>) {
                    base.put(k, mergeRec((Map<String,Object>) b, (Map<String,Object>) a));
                } else {
                    // Flow wins: keep base value
                }
            }
        }
        return base;
    }

    /* =========================
       HTTP with light retries
       ========================= */
    public static HttpResponse sendWithRetries(HttpRequest req, Integer maxRetries) {
        if (maxRetries == null || maxRetries < 1) maxRetries = 1;
        Http http = new Http();
        HttpResponse lastRes = null;

        for (Integer attempt = 1; attempt <= maxRetries; attempt++) {
            try {
                lastRes = http.send(req);
                Integer code = lastRes.getStatusCode();
                if (code == 429 || (code >= 500 && code <= 599)) {
                    if (attempt < maxRetries) {
                        // No sleep/jitter available in Apex; immediate retry
                        continue;
                    }
                }
                return lastRes; // success or non-retriable
            } catch (Exception e) {
                if (attempt >= maxRetries) throw e;
                // else loop to retry
            }
        }
        // Fallback: return last response (may be null or non-2xx)
        return lastRes;
    }
}