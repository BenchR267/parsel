//
//  Lexical.swift
//  ParselPackageDescription
//
//  Created by Benjamin Herzog on 21.08.17.
//

/// L is the shortcut for Lexical namespace
public typealias L = Lexical

/// Lexical is the namespace for Lexical parsers (you can also use shorthand L if you prefer)
public enum Lexical {
    
    /// Errors that could occur while lexical parsing
    public enum Error: ParseError {
        
        /// an unexpected token occured
        ///
        /// - expected: a description of what was expected
        /// - got: the actual value at that position
        case unexpectedToken(expected: String, got: String)
    }
    
    // MARK: - strings
    
    /// Parses one Character from a given String
    public static let char = Parser<String, Character> { str in
        guard let first = str.characters.first else {
            return .fail(Error.unexpectedToken(expected: "char", got: String(str.prefix(1))))
        }
        return .success(result: first, rest: String(str.dropFirst()))
    }
    
    /// Parses a specific Character from a given String
    ///
    /// - Parameter c: the Character that should be parsed
    /// - Returns: a parser that parses that one Character from a given String
    public static func char(_ c: Character) -> Parser<String, Character> {
        return Parser { str in
            guard let first = str.characters.first, first == c else {
                return .fail(Error.unexpectedToken(expected: String(c), got: String(str.prefix(1))))
            }
            return .success(result: first, rest: String(str.dropFirst()))
        }
    }
    
    /// Parses one char that is part of the ascii table
    public static let asciiChar = char.filter { parsed in
        guard parsed.unicodeScalars.first(where: { !$0.isASCII }) == nil else {
            return Error.unexpectedToken(expected: "ascii", got: String(parsed))
        }
        return nil
    }
    
    /// Parses a string that consists only of characters from the ascii range
    public static let asciiString = asciiChar.atLeastOnce ^^ { String($0) }
    
    /// Parses a given String from a String.
    ///
    /// - Parameter s: the String which should be parsed
    /// - Returns: a parser that parses that String
    public static func string(_ s: String) -> Parser<String, String> {
        return Parser { str in
            guard str.hasPrefix(s) else {
                return .fail(Error.unexpectedToken(expected: s, got: String(str.prefix(s.count))))
            }
            return .success(result: s, rest: String(str.dropFirst(s.count)))
        }
    }
    
    /// Parses a string with the given length
    ///
    /// - Parameter length: the length the string should have
    /// - Returns: a parser that parses a string with exactly the given length
    public static func string(length: Int) -> Parser<String, String> {
        return char.exactly(count: length) ^^ { String($0) }
    }
    
    // MARK: - numbers
    
    /// Parses a digit [0-9] from a given String
    public static let digit = Parser<String, Int> { str in
        guard let first = str.characters.first, let number = Int(String(first)) else {
            return .fail(Error.unexpectedToken(expected: "digit", got: String(str.prefix(1))))
        }
        return .success(result: number, rest: String(str.dropFirst()))
    }
    
    /// Parses a binary digit (0 or 1)
    public static let binaryDigit = digit.filter { parsed in
        guard (0...1).contains(parsed) else {
            return Error.unexpectedToken(expected: "0 or 1", got: "\(parsed)")
        }
        return nil
    }
    
    /// A parser for numbers of the format `0b10110110`
    public static let binaryNumber = (string("0b") >~ binaryDigit.atLeastOnce) ^^ { digits in
        return buildNumber(digits: digits, base: 2)
    }
    
    /// Parses an octal digit (0 to 7)
    public static let octalDigit = digit.filter { parsed in
        guard (0...7).contains(parsed) else {
            return Error.unexpectedToken(expected: "0 to 7", got: "\(parsed)")
        }
        return nil
    }
    
    /// A parser for numbers of the format `0o12372106`
    public static let octalNumber = (string("0o") >~ octalDigit.atLeastOnce) ^^ { digits in
        return buildNumber(digits: digits, base: 8)
    }
    
    /// Parses a hexadecimal digit (0 to 15)
    public static let hexadecimalDigit = char.map { parsed -> Int in
        let ascii = asciiValue(from: parsed)
        if (asciiValue(from: "a")...asciiValue(from: "z")).contains(ascii) {
            return ascii - asciiValue(from: "a") + 10
        } else if (asciiValue(from: "A")...asciiValue(from: "Z")).contains(ascii) {
            return ascii - asciiValue(from: "A") + 10
        } else if (asciiValue(from: "0")...asciiValue(from: "9")).contains(ascii) {
            return ascii - asciiValue(from: "0")
        } else {
            return -1
        }
        }.filter { parsedNumber in
            guard (0...15).contains(parsedNumber) else {
                return Error.unexpectedToken(expected: "0 to 15", got: "\(parsedNumber)")
            }
            return nil
    }
    
    /// A parser for numbers of the format `0xdeadbeaf` or `0xDEADBEAF`
    public static let hexadecimalNumber = ((string("0x") | string("0X")) >~ hexadecimalDigit.atLeastOnce) ^^ { digits in
        return buildNumber(digits: digits, base: 16)
    }
    
    /// Parses a decimal number
    public static let decimalNumber = digit.atLeastOnce ^^ { digits in
        return buildNumber(digits: digits, base: 10)
    }
    
    /// Parses a number in hexadecimal, octal, binary or decimal format
    public static let number = hexadecimalNumber | octalNumber | binaryNumber | decimalNumber
    
    /// Parses a floating number from String to Double (0.123; 0,123; …)
    public static let floatingNumber = "[0-9]+([\\.,][0-9]+)?".r ^^ { str -> Double in
            let cleaned = str.replacingOccurrences(of: ",", with: ".")
            return Double(cleaned)!
        }
    
    // MARK: - Common characters
    
    /// Parses the `+` sign
    public static let plus = char("+")
    
    /// Parses the `-` sign
    public static let minus = char("-")
    
    /// Parses the `*` sign
    public static let multiply = char("*")
    
    /// Parses the `/` sign
    public static let divide = char("/")
    
    /// Parses the `=` sign
    public static let assign = char("=")
    
    /// Parses the `==` sign
    public static let equal = (assign ~ assign) ^^ { String([$0, $1]) }
    
    // MARK: - Whitespaces
    
    /// Parses one space character
    public static let space = char(" ")
    
    /// Parses a new line `\n` character
    public static let newLine = char("\n")
    
    /// Parses a new line `\n` character
    public static let carriageReturn = char("\r\n")
    
    /// Parses a tab `\t` character
    public static let tab = char("\t")
    
    /// Parses exactly one whitespace
    public static let oneWhitespace = space | newLine | carriageReturn | tab
    
    /// Parses at least one whitespace
    public static let whitespaces = oneWhitespace.atLeastOnce
    
    // MARK: - Helpers
    
    /// Returns the ascii value of the given chars first unicode scalar or -1 if empty.
    ///
    /// - Parameter char: the char to evaluate
    /// - Returns: its ascii value or -1 if no unicodescalar
    private static func asciiValue(from char: Character) -> Int {
        return Int(char.unicodeScalars.first!.value)
    }
    
    /// Builds a number from a given array of digits.
    ///
    /// - Parameters:
    ///   - digits: the digits from left to right
    ///   - base: the base of the numbers system
    /// - Returns: the value as an integer
    private static func buildNumber(digits: [Int], base: Int) -> Int {
        return digits.reduce(0) { res, e in
            return res * base + e
        }
    }
    
}
