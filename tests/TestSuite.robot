#!/usr/bin/env python3

*** Settings ***
Library  Collections
Library  OperatingSystem
Library  Process
Library  String
Library  Telnet
Library  XML

*** Test Cases ***
Use different Log Keywords
    Log    This message is written to the log
