require "yaml"
require "crypto/bcrypt/password"
require "option_parser"

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

        File.open("config.yml", "w") { |f| YAML.dump({
            server_name: server_name,
            port: port,
            password: password,
            admin_password: admin_password,
            is_private: is_private,
            canvas_size: canvas_size
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