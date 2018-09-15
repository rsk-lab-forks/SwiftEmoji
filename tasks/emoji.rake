namespace :emoji do
  
  task :environment do |t|
    $ROOT_DIR = File.expand_path("..", t.application.rakefile)
  end

  desc %{Generates swift sources from Unicode Emoji data files.}
  task :generate_sources => :environment do
    sequences_path = File.join($ROOT_DIR, "tasks", "emoji", "emoji-sequences.txt")
    sequences = Emoji.parse_entries(sequences_path)

    zwj_sequences_path = File.join($ROOT_DIR, "tasks", "emoji", "emoji-zwj-sequences.txt")
    zwj_sequences = Emoji.parse_entries(zwj_sequences_path)
    
    test_path =  File.join($ROOT_DIR, "tasks", "emoji", "emoji-test.txt")
    test = Emoji.parse_entries(test_path)
    
    emoji = test + sequences - (test & sequences)
    emoji = emoji + zwj_sequences - (emoji & zwj_sequences)
    
    swift_source_code = <<-SWIFT
//
// DO NOT EDIT. This file was auto-generated from the Unicode data files located at:
//
//    https://www.unicode.org/Public/emoji/11.0/
//
// To regenerate it, use the rake tasks in the SwiftEmoji project.
//

///
/// A Swift-ified version of Unicode's Emoji data files, located at:
///
///   https://www.unicode.org/Public/emoji/11.0/
///
public class EmojiData {
    
    ///
    /// Patterns that match emoji forms, excluding emoji sequences and Zero-Width-Joiner (ZWJ)
    /// sequences, which should be in keyboards and which should also be displayed/processed.
    ///
    public static let EmojiPatterns:[String] = [
        #{Emoji::Entry.to_swift_array_entries(emoji).join("\n        ")}
    ]
    
    ///
    /// Patterns that match emoji sequences. This includes keycap characters, flags, and skintone
    /// variants, but not Zero-Width-Joiner (ZWJ) sequences used for "family" characters like
    /// "👨‍👩‍👧‍👧".
    ///
    public static let SequencePatterns:[String] = [
        #{Emoji::Entry.to_swift_array_entries(sequences).join("\n        ")}
    ]
    
    ///
    /// Patterns that match Zero-Width-Joiner (ZWJ) sequences used for "family" characters like
    /// "👨‍👩‍👧‍👧".
    ///
    public static let ZWJSequencePatterns:[String] = [
        #{Emoji::Entry.to_swift_array_entries(zwj_sequences).join("\n        ")}
    ]
    
    private init() {
        // Prevent instantiation.
    }
}
SWIFT
    
    source_file = File.join($ROOT_DIR, "Sources", "EmojiData.swift")
    File.open(source_file, "w") { |f|
      f << swift_source_code
    }
    
  end
  
end

module Emoji
  
  def self.parse_entries(path)
    entries = []
  
    File.open(path) do |f|
      f.each_line do |line|
        match = line.match(/^\s*([^#]+?)\s*(;\s*([^#]+)\s*)?\#(.*)$/)
        if match != nil
          codepoints = match[1]
          comment = match[4]
          
          entries << Emoji::Entry.new(codepoints, comment)
        end
      end
    end
  
    entries.sort { |a,b| a.codepoints <=> b.codepoints }
  end
  
  def self.hex_code_to_escape(hex)
    if hex.length == 4
      "\\\\u#{hex}"
    elsif hex.length == 5
      "\\\\U000#{hex}"
    else
      abort "Unknown hex code: #{hex}"
    end
  end
  
  class Entry
    
    attr_reader :codepoints, :comment
    
    def initialize(codepoints, comment)
      @codepoints = codepoints.strip
      @comment = comment.strip
    end
    
    def to_swift_pattern
      parts = codepoints.split /\s+/
      pattern = parts.map do |p|
        if p =~ /^([a-f0-9]+)$/i
          Emoji.hex_code_to_escape($1)
        else
          abort "Unknown line: #{codepoints}"
        end
      end.join("")
      
      return pattern
    end
    
    def self.to_swift_array_entries(entries)
      patterns = []
      entries.each_with_index do |entry, index|
        if index == entries.length - 1
          patterns << "\"#{entry.to_swift_pattern}\"     // #{entry.comment}"
        else
          patterns << "\"#{entry.to_swift_pattern}\",    // #{entry.comment}"
        end
      end
      patterns
    end
    
    def ==(other)
      other.class == self.class && other.state == self.state
    end
    
    alias_method :eql?, :==
    
    def hash
      self.state.hash
    end
    
    protected
    
    def state
      [@codepoints]
    end
    
  end
  
end
