//
//  main.m
//  GlobalChat Server
//
//  Created by Jonathan Silverman on 25/09/2012.
//  Copyright (c) 2012 Jonathan Silverman. All rights reserved.
//

#import <Cocoa/Cocoa.h>

#import <MacRuby/MacRuby.h>

int main(int argc, char *argv[])
{
    return macruby_main("rb_main.rb", argc, argv);
}
