//
//  String.swift
//  Primal
//
//  Created by Nikola Lukovic on 20.2.23..
//

import Foundation

extension Character {
    /// A simple emoji is one scalar and presented to the user as an Emoji
    var isSimpleEmoji: Bool {
        guard let firstScalar = unicodeScalars.first else { return false }
        return firstScalar.properties.isEmoji && firstScalar.value > 0x238C
    }

    /// Checks if the scalars will be merged into an emoji
    var isCombinedIntoEmoji: Bool { unicodeScalars.count > 1 && unicodeScalars.first?.properties.isEmoji ?? false }

    var isEmoji: Bool { isSimpleEmoji || isCombinedIntoEmoji }
}

extension String {
    var isSingleEmoji: Bool { count == 1 && containsEmoji }

    var containsEmoji: Bool { contains { $0.isEmoji } }

    var containsOnlyEmoji: Bool { !isEmpty && !contains { !$0.isEmoji } }

    var emojiString: String { emojis.map { String($0) }.reduce("", +) }

    var emojis: [Character] { filter { $0.isEmoji } }

    var emojiScalars: [UnicodeScalar] { filter { $0.isEmoji }.flatMap { $0.unicodeScalars } }
}

extension String : Identifiable {
    public var id: String {
        return UUID().uuidString
    }
    
    var isValidURL: Bool {
        let detector = try! NSDataDetector(types: NSTextCheckingResult.CheckingType.link.rawValue)
        if let match = detector.firstMatch(in: self, options: [], range: NSRange(location: 0, length: self.utf16.count)) {
            // it is a link, if the match covers the whole string
            return match.range.length == self.utf16.count
        } else {
            return false
        }
    }
    
    var isEmail: Bool {
        let emailRegEx = "[A-Z0-9a-z._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,64}"
        return NSPredicate(format:"SELF MATCHES %@", emailRegEx).evaluate(with: self)
    }
    
    var isValidURLAndIsImage: Bool {
        isValidURL && isImageURL
    }
    
    var isImageURL: Bool {
        hasSuffix(".jpg") || hasSuffix(".jpeg") || hasSuffix(".webp") || hasSuffix(".png") || hasSuffix(".gif") || hasSuffix("format=png")
    }
    
    var isVideoURL: Bool {
        isVideoButNotYoutube || isYoutubeVideo
    }
    
    var isVideoButNotYoutube: Bool {
        hasSuffix(".mov") || hasSuffix(".mp4")
    }
    
    var isYoutubeVideo: Bool {
        contains("youtube.com/watch?") || contains("youtu.be")
    }
    
    var isHashtag: Bool {
        let hashtagPattern = "(?:\\s|^)#[^\\s!@#$%^&*(),.?\":{}|<>]+"
        
        guard let hashtagRegex = try? Regex(hashtagPattern) else {
            print("Unable to create hashtag pattern regex")
            return false
        }
        
        if let matches = self.wholeMatch(of: hashtagRegex) {
            return !matches.isEmpty
        }
        
        return false
    }
    
    var isNip08Mention: Bool {
        let mentionPattern = "\\#\\[([0-9]*)\\]"
        
        guard let mentionRegex = try? Regex(mentionPattern) else {
            print("Unable to create mention pattern regex")
            return false
        }
        
        if let matches = self.wholeMatch(of: mentionRegex) {
            return !matches.isEmpty
        }
        
        return false
    }
    
    var isNip27Mention: Bool {
        let mentionPattern = "\\bnostr:((npub|nprofile)1\\w+)\\b|#\\[(\\d+)\\]"
        
        guard let mentionRegex = try? Regex(mentionPattern) else {
            print("Unable to create mention pattern regex")
            return false
        }
        
        if let matches = self.wholeMatch(of: mentionRegex) {
            return !matches.isEmpty
        }
        
        return false
    }

    func extractTagsMentionsAndURLs() -> [String] {
        let hashtagPattern = "(?:\\s|^)#[^\\s!@#$%^&*(),.?\":{}|<>]+"
        let nip08MentionPattern = "\\#\\[([0-9]*)\\]"
        let nip27MentionPattern = "\\bnostr:((npub|nprofile)1\\w+)\\b|#\\[(\\d+)\\]"

        guard
            let hashtagRegex = try? NSRegularExpression(pattern: hashtagPattern, options: []),
            let mentionRegex = try? NSRegularExpression(pattern: nip08MentionPattern, options: []),
            let profileMentionRegex = try? NSRegularExpression(pattern: nip27MentionPattern, options: []),
            let urlDetector = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.link.rawValue)
        else {
            return []
        }
        
        var ranges: Set<Range<String.Index>> = []
        hashtagRegex.enumerateMatches(in: self, options: [], range: NSRange(self.startIndex..., in: self)) { match, _, _ in
            if let matchRange = match?.range, let range = Range(matchRange, in: self) {
                ranges.insert(range)
            }
        }
        mentionRegex.enumerateMatches(in: self, options: [], range: NSRange(self.startIndex..., in: self)) { match, _, _ in
            if let matchRange = match?.range, let range = Range(matchRange, in: self) {
                ranges.insert(range)
            }
        }
        profileMentionRegex.enumerateMatches(in: self, options: [], range: NSRange(self.startIndex..., in: self)) { match, _, _ in
            if let matchRange = match?.range, let range = Range(matchRange, in: self) {
                ranges.insert(range)
            }
        }
        urlDetector.enumerateMatches(in: self, range: NSRange(self.startIndex..., in: self)) { match, _, _ in
            if let matchRange = match?.range, let range = Range(matchRange, in: self) {
                ranges.insert(range)
            }
        }
        var result: Set<String> = []
        var currentIndex = self.startIndex
        for range in ranges.sorted(by: { $0.lowerBound < $1.lowerBound }) {
            if currentIndex < range.lowerBound {
                result.insert(String(self[currentIndex..<range.lowerBound]).trimmingCharacters(in: .whitespacesAndNewlines).replacingOccurrences(of: "\n", with: ""))
            }
            result.insert(String(self[range]).trimmingCharacters(in: .whitespacesAndNewlines).replacingOccurrences(of: "\n", with: ""))
            currentIndex = range.upperBound
        }
        result.insert(String(self[currentIndex...]))
        return Array(result)
    }
    
    func removingDoubleEmptyLines() -> String {
        let lines = split(separator: "\n", omittingEmptySubsequences: false)
        let lastLine = lines.last
        
        let trimmedLines = lines.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
        let removeDoubleEmptyLine = zip(zip(trimmedLines, trimmedLines.dropFirst()), lines).filter { (arg0, _) in
            let (line, nextLine) = arg0
            return !(line.isEmpty && nextLine.isEmpty)
        }
        var text = removeDoubleEmptyLine.map({ $0.1 }).joined(separator: "\n")
        if let lastLine {
            text += "\n\(lastLine)"
        }
        return text
    }
}
