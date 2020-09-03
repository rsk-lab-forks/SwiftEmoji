namespace :emoji do
  
  task :environment do |t|
    $ROOT_DIR = File.expand_path("..", t.application.rakefile)
  end

  desc %{Generates swift sources from Unicode Emoji data files.}
  task :generate_sources => :environment do
    zwj_sequences_path = File.join($ROOT_DIR, "tasks", "emoji", "emoji-zwj-sequences.txt")
    zwj_sequences = Emoji.parse_entries(zwj_sequences_path)
    
    variation_sequences_path = File.join($ROOT_DIR, "tasks", "emoji", "emoji-variation-sequences.txt")
    variation_sequences = Emoji.parse_entries(variation_sequences_path)
    
    other_sequences_path = File.join($ROOT_DIR, "tasks", "emoji", "emoji-sequences.txt")
    other_sequences = Emoji.parse_entries(other_sequences_path)
    
    test_path =  File.join($ROOT_DIR, "tasks", "emoji", "emoji-test.txt")
    test = Emoji.parse_entries(test_path)
    
    other_sequences = other_sequences.select { |e| e.type_field.start_with?("Basic_Emoji") == false }
    
    emoji = test - zwj_sequences - variation_sequences - other_sequences
    
    swift_source_code = <<-SWIFT
//
// DO NOT EDIT. This file was auto-generated from the Unicode data files located at:
//
//    https://www.unicode.org/Public/emoji/13.0/
//
// To regenerate it, use the rake tasks in the SwiftEmoji project.
//

///
/// A Swift-ified version of Unicode's Emoji data files, located at:
///
///   https://www.unicode.org/Public/emoji/13.0/
///
public class EmojiData {
    
    ///
    /// Patterns that match emoji forms, excluding Zero-Width-Joiner (ZWJ), variation and
    /// other sequences.
    ///
    public static let EmojiPatterns:[String] = [
        #{Emoji::Entry.to_swift_array_entries(emoji).join("\n        ")}
    ]
    
    ///
    /// Patterns that match other sequences. This includes keycap characters, flags, and skintone
    /// variants, but not Zero-Width-Joiner (ZWJ) sequences used for "family" characters like
    /// "👨‍👩‍👧‍👧".
    ///
    public static let OtherSequencesPatterns:[String] = [
        #{Emoji::Entry.to_swift_array_entries(other_sequences).join("\n        ")}
    ]
    
    ///
    /// Patterns that match variation sequences.
    ///
    public static let VariationSequencesPatterns:[String] = [
        #{Emoji::Entry.to_swift_array_entries(variation_sequences).join("\n        ")}
    ]
    
    ///
    /// Patterns that match Zero-Width-Joiner (ZWJ) sequences used for "family" characters like
    /// "👨‍👩‍👧‍👧".
    ///
    public static let ZWJSequencesPatterns:[String] = [
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
          type_field = match[3]
          comment = match[4]
          
          entries << Emoji::Entry.new(codepoints, type_field, comment)
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
    
    attr_reader :codepoints, :type_field, :comment
    
    def initialize(codepoints, type_field, comment)
      @codepoints = codepoints.strip
      if type_field != nil
        @type_field = type_field.strip
      end
      @comment = comment.strip
    end
    
    def to_swift_pattern
      parts = codepoints.split /\s+/
      pattern = parts.map do |p|
        if p =~ /^([a-f0-9]+)$/i
          Emoji.hex_code_to_escape($1)
        elsif p =~ /^([a-f0-9]+)\.\.([a-f0-9]+)$/i
          start_code = Emoji.hex_code_to_escape($1)
          end_code = Emoji.hex_code_to_escape($2)

          "[#{start_code}-#{end_code}]"
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
