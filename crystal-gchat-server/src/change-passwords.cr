require "yaml"
require "crypto/bcrypt/password"
require "option_parser"
require "atomic_write"
require "big"

module Globals
  def self.interactive
    puts "enter server name"
    server_name = gets.to_s.chomp

    puts "enter port"
    port = gets.to_s.chomp.to_i

    puts "enter login password"
    password = Crypto::Bcrypt::Password.create(gets.to_s.chomp, cost: 10).to_s

    puts "enter admin password"
    admin_password = Crypto::Bcrypt::Password.create(gets.to_s.chomp, cost: 10).to_s

    puts "should appear in server list? y/n"
    is_private = gets.to_s.chomp == "n"

    puts "canvas size in widthxheight"
    canvas_size = gets.to_s.chomp

    puts "serverside chat replay (scrollback) y/n"
    scrollback = gets.to_s.chomp == "y"

    puts "how many lines to replay?"
    buffer_line_limit = gets.to_s.chomp.to_i

    puts "server file size limit (canvas, replay) in bytes (ie 10e+7 for 100 megabytes)"
    file_size_limit = gets.to_s.chomp.to_f64

    File.atomic_write("config.yml") { |f| YAML.dump({
      server_name:       server_name,
      port:              port,
      password:          password,
      admin_password:    admin_password,
      is_private:        is_private,
      canvas_size:       canvas_size,
      scrollback:        scrollback,
      buffer_line_limit: buffer_line_limit,
      file_size_limit:   file_size_limit,
    }, f) }

    exit
  end

  OptionParser.parse do |parser|
    parser.banner = "Usage: change-password [arguments]"
    parser.on("-i", "--interactive", "Enter the config options from the terminal") { Globals.interactive }
    parser.on("-h", "--help", "Show this help") do
      puts parser
      exit
    end
    parser.invalid_option do |flag|
      STDERR.puts "ERROR: #{flag} is not a valid option."
      STDERR.puts parser
      exit(1)
    end
  end
end
