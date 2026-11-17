import Foundation

/// Localized widget strings (spec 055), mirroring the Android resources.
/// Implemented in Swift (not a string catalog) so no extra Xcode resource
/// wiring is needed. Counts are capped at "99+" to fit the compact layout.
enum WidgetL10n {
    static let statCap = 999

    private static var lang: String {
        if #available(iOS 16.0, *) {
            return Locale.current.language.languageCode?.identifier ?? "en"
        } else {
            return Locale.current.languageCode ?? "en"
        }
    }

    private static func capped(_ n: Int) -> String {
        n > statCap ? "\(statCap)+" : "\(n)"
    }

    /// CLDR plural category for Russian (one / few / many).
    private static func ru(_ n: Int, _ one: String, _ few: String, _ many: String) -> String {
        let mod10 = n % 10
        let mod100 = n % 100
        if mod10 == 1 && mod100 != 11 { return one }
        if (2...4).contains(mod10) && !(12...14).contains(mod100) { return few }
        return many
    }

    static func entries(_ n: Int) -> String {
        let v = capped(n)
        // Select the plural form on the capped count so "999+" uses the plural
        // (e.g. Russian "many"), not the raw count's category.
        let p = min(n, statCap + 1)
        switch lang {
        case "de": return p == 1 ? "\(v) Eintrag" : "\(v) Einträge"
        case "es": return p == 1 ? "\(v) entrada" : "\(v) entradas"
        case "fr": return p <= 1 ? "\(v) entrée" : "\(v) entrées"
        case "it": return p == 1 ? "\(v) voce" : "\(v) voci"
        case "ja": return "\(v) 件"
        case "ko": return "기록 \(v)개"
        case "pt": return p == 1 ? "\(v) entrada" : "\(v) entradas"
        case "ru": return "\(v) \(ru(p, "запись", "записи", "записей"))"
        case "tr": return "\(v) kayıt"
        case "zh": return "\(v) 条"
        default: return p == 1 ? "\(v) entry" : "\(v) entries"
        }
    }

    static func days(_ n: Int) -> String {
        let v = capped(n)
        let p = min(n, statCap + 1)
        switch lang {
        case "de": return p == 1 ? "\(v) Tag" : "\(v) Tage"
        case "es": return p == 1 ? "\(v) día" : "\(v) días"
        case "fr": return p <= 1 ? "\(v) jour" : "\(v) jours"
        case "it": return p == 1 ? "\(v) giorno" : "\(v) giorni"
        case "ja": return "\(v) 日"
        case "ko": return "\(v)일"
        case "pt": return p == 1 ? "\(v) dia" : "\(v) dias"
        case "ru": return "\(v) \(ru(p, "день", "дня", "дней"))"
        case "tr": return "\(v) gün"
        case "zh": return "\(v) 天"
        default: return p == 1 ? "\(v) day" : "\(v) days"
        }
    }

    /// "used / total today" with a localized "today".
    static func quota(used: Int, limit: Int) -> String {
        let n = "\(used) / \(limit)"
        switch lang {
        case "de": return "\(n) heute"
        case "es": return "\(n) hoy"
        case "fr": return "\(n) aujourd’hui"
        case "it": return "\(n) oggi"
        case "ja": return "今日 \(n)"
        case "ko": return "오늘 \(n)"
        case "pt": return "\(n) hoje"
        case "ru": return "\(n) сегодня"
        case "tr": return "bugün \(n)"
        case "zh": return "今天 \(n)"
        default: return "\(n) today"
        }
    }

    static var description: String {
        switch lang {
        case "de": return "Starte eine Aufnahme und sieh deine Journaling-Statistiken."
        case "es": return "Empieza a grabar y consulta tus estadísticas de diario."
        case "fr": return "Lancez un enregistrement et consultez vos statistiques de journal."
        case "it": return "Inizia a registrare e guarda le statistiche del diario."
        case "ja": return "録音を始めて、ジャーナルの統計を確認しましょう。"
        case "ko": return "녹음을 시작하고 저널링 통계를 확인하세요."
        case "pt": return "Comece a gravar e veja suas estatísticas de diário."
        case "ru": return "Начните запись и смотрите статистику дневника."
        case "tr": return "Kayda başlayın ve günlük istatistiklerinizi görün."
        case "zh": return "开始录音并查看你的日记统计。"
        default: return "Start recording and see your journaling stats."
        }
    }
}
