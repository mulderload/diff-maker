# MulderLoad's Diff Maker

## Description 

A powershell script to extract a "diff patch" between 2 folders recursively.

The main goal is to help myself writing patch for www.mulderland.com, so it's very NSIS oriented.

But I've decided to open source it if it can help other people.

It will :
- add new files to the output folder
- add modified files to the output folder
- write renamed files to nsis.txt
- write moved files to nsis.txt
- write deleted files to nsis.txt

I used it to write my "Alpha Protocol GOG Update for Steam", for example.

## Usage

Right click on "diff-maker.ui.ps1" > Run with Powershell
