package com.parentalcontrol.kidsagent.safety

import com.parentalcontrol.kidsagent.data.model.RiskAlertPayload
import java.util.regex.Pattern

object RiskDetector {

    // Innocent Arabic words that happen to contain substrings like "كس", "زب", "مني"
    private val ARABIC_INNOCENT_WORDS = setOf(
        // Words containing "كس"
        "تكسي", "تاكسي", "التكسي", "التاكسي", "تكسيات", "بالتكسي", "للتاكسي",
        "عاكس", "عاكسة", "عاكسه", "العاكس", "العاكسة", "معكوس", "عكس", "العكس", "انعكاس", "الانعكاس",
        "كسر", "كسرنا", "تكسير", "انكسار", "كسول", "الكسول", "كسلان",
        "جرافيكس", "جرافكس", "كروكس", "الكروكس", "فيليكس", "أوكسير", "اوكسير",
        "اكستريم", "إكستريم", "سكسوكة", "تكساس", "فاكس", "أرثوذكس", "ارثوذكس",
        "ماكس", "ماكسي", "كسكسي", "كسكس", "سكسفون",

        // Words containing "زب"
        "زبون", "الزبون", "للزبون", "زبائن", "الزبائن", "للزبائن", "زبائننا", "لزبائننا",
        "زبادي", "الزبادي", "زبدة", "الزبدة", "كزبرة", "الكزبرة", "زبيد", "زبيدي",

        // Words containing "مني"
        "منير", "منيرة", "منيه", "منية", "أمنية", "امنية", "أمنيات", "امنيات", "أمنياتنا",
        "نتمنى", "اتمنى", "أتمنى", "تمنى", "تمنياتنا", "تمنياتي",
        "يمنح", "يمنحكم", "يمنحنا", "يمن", "اليمن", "يمني", "يمنية",
        "مؤمنين", "متمنين", "تثمين", "ألماني", "الماني", "ألمانيا", "المانيا", "عثماني", "ميني"
    )

    // Regex for standalone Arabic vulgar keywords (ensures they are NOT part of innocent words)
    private val VULGAR_ARABIC_PATTERNS = listOf(
        Pattern.compile("(?:^|[\\s\\p{Punct}])(ال)?(كس|طيز|شذوذ|سحاق|زب)(ك|ه|ها|هم|كم)?(?=[\\s\\p{Punct}]|$)", Pattern.CASE_INSENSITIVE or Pattern.UNICODE_CASE),
        Pattern.compile("(?:^|[\\s\\p{Punct}])(جنس|سكس|إباحي|اباحي|عاري|تعري)(?=[\\s\\p{Punct}]|$)", Pattern.CASE_INSENSITIVE or Pattern.UNICODE_CASE)
    )

    // Bullying / self-harm keywords
    private val BULLYING_ARABIC = listOf(
        "انتحار", "انتحر", "اموت", "اقتل", "اقتلك", "اذبحك", "اكرهك", "حقير", "سافل", "حمار",
        "يا غبي", "تافه", "اريد اموت", "اكره حياتي"
    )

    // Stranger danger phrases
    private val STRANGER_ARABIC = listOf(
        "وين بيتكم", "وين ساكن", "تعال نلتقي", "لا تكول لاهلك", "لا تكول لماما", "لا تكول لبابا",
        "لا تخبر اهلك", "لا تخبر احدا", "سر بيناتنا", "سر بيننا", "دز صورتك", "دزي صورتج"
    )

    // Substances
    private val SUBSTANCES_ARABIC = listOf(
        "مخدرات", "حشيش", "كبتاجون", "حبوب مخدرة", "فودو", "جوينت", "شرب عرق",
        "خمر", "ويسكي"
    )

    // English word-boundary regex patterns (prevents "die" matching "diet", "foodie", "fried", etc.)
    private val ENGLISH_BULLYING = Pattern.compile(
        "\\b(suicide|kill\\s+yourself|kill\\s+you|hate\\s+you|cut\\s+myself|loser|ugly|die)\\b",
        Pattern.CASE_INSENSITIVE
    )

    private val ENGLISH_INAPPROPRIATE = Pattern.compile(
        "\\b(porn|xxx|nude|sex|erotic|nsfw|naked)\\b",
        Pattern.CASE_INSENSITIVE
    )

    private val ENGLISH_STRANGER = Pattern.compile(
        "\\b(meet\\s+me|our\\s+secret|keep\\s+it\\s+secret|don't\\s+tell\\s+your\\s+parents|send\\s+your\\s+pic|where\\s+do\\s+you\\s+live|come\\s+over)\\b",
        Pattern.CASE_INSENSITIVE
    )

    private val ENGLISH_SUBSTANCES = Pattern.compile(
        "\\b(weed|drugs?|alcohol|cocaine|marijuana)\\b",
        Pattern.CASE_INSENSITIVE
    )

    // Dynamic Safe Whitelist (Controlled by Parent via Web/App)
    private val dynamicSafePatterns = java.util.concurrent.ConcurrentHashMap.newKeySet<String>()

    fun setSafePatterns(patterns: Collection<String>) {
        dynamicSafePatterns.clear()
        patterns.forEach { p ->
            val clean = p.trim().lowercase()
            if (clean.isNotEmpty()) {
                dynamicSafePatterns.add(clean)
            }
        }
    }

    fun addSafePattern(pattern: String) {
        val clean = pattern.trim().lowercase()
        if (clean.isNotEmpty()) {
            dynamicSafePatterns.add(clean)
        }
    }

    fun getSafePatterns(): Set<String> = dynamicSafePatterns

    fun isPatternSafe(lowerText: String, lowerSource: String): Boolean {
        for (pat in dynamicSafePatterns) {
            if (pat.isEmpty()) continue
            if (lowerText.contains(pat) || lowerSource.contains(pat)) {
                return true
            }
        }
        return false
    }

    fun scan(text: String, source: String): RiskAlertPayload? {
        if (text.isBlank()) return null

        val lower = text.lowercase()
        val lowerSource = source.lowercase()

        // -1. Whitelist Check: If parent marked this phrase or source as SAFE, ignore completely
        if (isPatternSafe(lower, lowerSource)) {
            return null
        }

        // 0. Pre-filter commercial, shopping, delivery, food & sports notifications
        if (isExemptContext(lower, source)) {
            // Still check for severe self-harm / suicide even in exempt sources
            if (lower.contains("انتحار") || lower.contains("انتحر") || lower.contains("suicide")) {
                return RiskAlertPayload(
                    category = "BULLYING",
                    severity = "CRITICAL",
                    snippet = extractSnippet(text, "انتحار"),
                    source = source,
                    matchedReason = "تم رصد عبارة إيذاء نفسي شديدة في $source"
                )
            }
            return null
        }

        // 1. Self-Harm & Bullying (Arabic)
        for (kw in BULLYING_ARABIC) {
            if (hasArabicWord(lower, kw)) {
                val sev = if (kw.contains("انتحار") || kw.contains("اموت") || kw.contains("اقتل")) "CRITICAL" else "HIGH"
                return RiskAlertPayload(
                    category = "BULLYING",
                    severity = sev,
                    snippet = extractSnippet(text, kw),
                    source = source,
                    matchedReason = "تم رصد عبارة تنمر أو إيذاء: '$kw' في $source"
                )
            }
        }

        // English Bullying (word boundary)
        val bullMatcher = ENGLISH_BULLYING.matcher(text)
        if (bullMatcher.find()) {
            val matched = bullMatcher.group()
            val sev = if (matched.contains("suicide", ignoreCase = true) || matched.contains("kill", ignoreCase = true) || matched.contains("die", ignoreCase = true)) "CRITICAL" else "HIGH"
            return RiskAlertPayload(
                category = "BULLYING",
                severity = sev,
                snippet = extractSnippet(text, matched),
                source = source,
                matchedReason = "تم رصد عبارة تنمر إنجليزية: '$matched' في $source"
            )
        }

        // 2. Inappropriate / Adult Content (Arabic with regex & innocent word check)
        for (pattern in VULGAR_ARABIC_PATTERNS) {
            val m = pattern.matcher(lower)
            while (m.find()) {
                val wholeMatched = m.group().trim()
                // Check if the matched token is an innocent word
                val cleanWord = wholeMatched.trim { it <= ' ' || it in ".,:;!؟?()\"'-_/" }
                if (!isArabicInnocentWord(cleanWord)) {
                    return RiskAlertPayload(
                        category = "INAPPROPRIATE",
                        severity = "CRITICAL",
                        snippet = extractSnippet(text, wholeMatched),
                        source = source,
                        matchedReason = "تم رصد لفظ غير لائق: '$cleanWord' في $source"
                    )
                }
            }
        }

        // English Inappropriate (word boundary)
        val inappMatcher = ENGLISH_INAPPROPRIATE.matcher(text)
        if (inappMatcher.find()) {
            val matched = inappMatcher.group()
            return RiskAlertPayload(
                category = "INAPPROPRIATE",
                severity = "CRITICAL",
                snippet = extractSnippet(text, matched),
                source = source,
                matchedReason = "تم رصد محتوى غير لائق: '$matched' في $source"
            )
        }

        // 3. Stranger Danger (Arabic)
        for (phrase in STRANGER_ARABIC) {
            if (lower.contains(phrase)) {
                return RiskAlertPayload(
                    category = "STRANGER",
                    severity = "HIGH",
                    snippet = extractSnippet(text, phrase),
                    source = source,
                    matchedReason = "تم رصد عبارة استدراج مشبوهة: '$phrase' في $source"
                )
            }
        }

        // English Stranger (phrase boundary, never match standalone technical "secret=" or "Secrets")
        val strangerMatcher = ENGLISH_STRANGER.matcher(text)
        if (strangerMatcher.find()) {
            val matched = strangerMatcher.group()
            return RiskAlertPayload(
                category = "STRANGER",
                severity = "HIGH",
                snippet = extractSnippet(text, matched),
                source = source,
                matchedReason = "تم رصد عبارة استدراج ومحادثة غريب: '$matched' في $source"
            )
        }

        // 4. Substances & Drugs (Arabic)
        // Note: Crystal Palace (كريستال بالاس) sports team check
        if (lower.contains("كريستال بالاس") || lower.contains("كرستال بالاس") || lower.contains("crystal palace")) {
            // Safe: English premier league football club
        } else if (hasArabicWord(lower, "كريستال") || hasArabicWord(lower, "كرستال")) {
            return RiskAlertPayload(
                category = "SUBSTANCES",
                severity = "HIGH",
                snippet = extractSnippet(text, "كريستال"),
                source = source,
                matchedReason = "تم رصد إشارة لمواد محظورة (كريستال) في $source"
            )
        }

        for (kw in SUBSTANCES_ARABIC) {
            if (hasArabicWord(lower, kw)) {
                return RiskAlertPayload(
                    category = "SUBSTANCES",
                    severity = "HIGH",
                    snippet = extractSnippet(text, kw),
                    source = source,
                    matchedReason = "تم رصد إشارة لمواد أو عقاقير محظورة: '$kw' في $source"
                )
            }
        }

        // English Substances (word boundary)
        val subMatcher = ENGLISH_SUBSTANCES.matcher(text)
        if (subMatcher.find()) {
            val matched = subMatcher.group()
            return RiskAlertPayload(
                category = "SUBSTANCES",
                severity = "HIGH",
                snippet = extractSnippet(text, matched),
                source = source,
                matchedReason = "تم رصد مواد أو عقاقير محظورة: '$matched' في $source"
            )
        }

        return null
    }

    private fun isExemptContext(lowerText: String, source: String): Boolean {
        val lowerSource = source.lowercase()

        // Known restaurant, delivery, transport or telecom sources
        val commercialSources = listOf(
            "mamnoon", "talabat", "toters", "hungerstation", "careem",
            "zain", "asiacell", "korek", "uber", "bolt", "kfc", "mcdonald"
        )
        if (commercialSources.any { lowerSource.contains(it) }) {
            return true
        }

        // Common commercial phrases in text
        val commercialIndicators = listOf(
            "خصومات بالمطاعم", "تطبيقات التكسي", "عروض وتخفيضات", "طلبك قيد", "تم توصيل",
            "كود الخصم", "كود التفعيل", "رمز التحقق", "د.ع", "ر.س", "دينار", "ألف دينار"
        )
        if (commercialIndicators.any { lowerText.contains(it) }) {
            return true
        }

        return false
    }

    private fun isArabicInnocentWord(word: String): Boolean {
        if (ARABIC_INNOCENT_WORDS.contains(word)) return true
        for (innocent in ARABIC_INNOCENT_WORDS) {
            if (word.contains(innocent)) return true
        }
        return false
    }

    private fun hasArabicWord(text: String, keyword: String): Boolean {
        // Look for the keyword surrounded by whitespace or punctuation
        val escaped = Pattern.quote(keyword)
        val p = Pattern.compile("(?:^|[\\s\\p{Punct}])$escaped(?=[\\s\\p{Punct}]|$)", Pattern.CASE_INSENSITIVE or Pattern.UNICODE_CASE)
        return p.matcher(text).find()
    }

    private fun extractSnippet(fullText: String, matchedKeyword: String): String {
        val idx = fullText.indexOf(matchedKeyword, ignoreCase = true)
        if (idx == -1) return fullText.take(100)
        val start = (idx - 30).coerceAtLeast(0)
        val end = (idx + matchedKeyword.length + 30).coerceAtMost(fullText.length)
        return (if (start > 0) "..." else "") + fullText.substring(start, end).trim() + (if (end < fullText.length) "..." else "")
    }
}
