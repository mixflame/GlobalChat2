all: bin

test:
	crystal spec

bin: clean
	crystal build -s --release -o crystal-gchat-server src/crystal-gchat-server.cr
	crystal build -s --release -o change-passwords src/change-passwords.cr

clean:
	rm -f crystal-gchat-server
	rm -f change-passwords

run:
	crystal run src/crystal-gchat-server.cr