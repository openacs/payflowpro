##### YOU SHOULD ONLY HAVE TO EDIT THE FOLLOWING VALUES
# AOLserver directory
NS_HOME=AOLSERVERROOT_DIRECTORY

# Directory where Software Development Kit was unpacked
SDK_HOME=PATH_TO_PAYFLOWPRO_SDK_LIBRARIES

# Location of the pfpro lib .so file.
SOFILE=PATH_TO_PAYFLOWPRO_SDK_SO_FILE/libpfpro.so
##### NOTHING BELOW THIS LINE SHOULD HAVE TO BE EDITED


CC=gcc

OBJS=verisign.o
MODULE=verisign.so

NS_CFLAGS = -D__unix__ -D__solaris__ -fpic -I$(NS_HOME)/include
MCK_CFLAGS = -I$(SDK_HOME)

CFLAGS = -Wall -g $(NS_CFLAGS) $(MCK_CFLAGS)
LIBS = -L$(SDK_HOME)
VERSION=1.0

all: verisign.so

%.o: %.c
	$(CC) $(CFLAGS) -c $<

verisign.so: verisign.o
	gcc -Xlinker -dy -Xlinker -G -o verisign.so $(SOFILE) verisign.o $(LDFLAGS) $(LIBS)

install: verisign.so
	cp verisign.so $(NS_HOME)/bin

clean:
	rm -rf *.o *.so *~ core a.out *.tar.gz
