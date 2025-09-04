#!/bin/bash

# Clean up the docs directory
rm -rf docs/*

# Create CNAME file
echo -n "blog.lum8rjack.com" > docs/CNAME
