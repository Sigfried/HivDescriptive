#!/usr/bin/bash

grep Version DESCRIPTION
echo
echo Current commit
git rev-parse --verify HEAD
echo
echo Current git status
git status
