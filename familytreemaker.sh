#!/bin/bash

#MIT License
#
#Copyright (c) 2021 user18130814200115-2
#
#Permission is hereby granted, free of charge, to any person obtaining a copy
#of this software and associated documentation files (the "Software"), to deal
#in the Software without restriction, including without limitation the rights
#to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
#copies of the Software, and to permit persons to whom the Software is
#furnished to do so, subject to the following conditions:
#
#The above copyright notice and this permission notice shall be included in all
#copies or substantial portions of the Software.
#
#THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
#IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
#FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
#AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
#LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
#OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
#SOFTWARE.

# Get the number of lines of the .tree file
lines=$(wc -l "$1")

# Initial settings for DOT, box shaped and no arrows
echo "digraph {	node [shape=box];edge [dir=none];rankdir=LR;constraint=false"

i=1
list=""
# First we loop over all lines to make setting for all persons in the tree
while [ $i -le ${lines%%$1} ]; do
    # Reset some variables
    sex=""
    year=""
    name=""
    # Get the contents of the line we are working on
    raw=$(pl "$i" "$1")
    # Parse the line so that it includes just the name of the person
    id=${raw#    }
    id=${id%% (*}
    # Arguments are added in brackets at the end of the line
    arguments=${raw#*(}
    arguments=${arguments%%)}
    # Split the arguments at the comma
    IFS=',' read -ra argarr <<< "$arguments"
    # Get the number of arguments 
    [ -z "$arguments" ] && n=0 || n="${#argarr[@]}"
    # Arguments are (in order) sex, birthyear and name
    [ $n -gt 0 ] && sex=${argarr[0]}
    [ $n -gt 1 ] && year=${argarr[1]}
    # If the name is not set, use the id instead
    [ $n -gt 2 ] && name=${argarr[2]} || name=$id
    # Print everyone with their $name, $birthyear and...
    # If the person is designated as Male, colour their box blue
    if [ "$sex" = "M" ]
    then
	echo "\"$id\"[style=filled,fillcolor=azure2];"
    # If they are female colour them orange
    elif [ "$sex" = "F" ]
    then
	echo "\"$id\"[style=filled,fillcolor=bisque];"
    fi
    echo "\"$id\"[label=\"$name\n$year\"];"
    i=$(expr "$i" + 1)
done

# Now we enter a new loop to generate the tree
i=1
while [ $i -le ${lines%%$1} ]; do
    # Get the contents of the line we are working on
    raw=$(pl "$i" "$1")
    # Parse the line so that it includes just the name of the person
    line=${raw#    }
    line=${line%% (*}

    # If we do not start with four spaces, then we are designating a household
    if [[ "$raw" != "    "* ]]
    then
	# The next line will designate the partner
	i=$(expr "$i" + 1)
	line2=$(pl "$i" "$1")
	line2=${line2#    }
	line2=${line2%% (*}
	# Each household is given a unique ID.
	# This id will get it's own (invisible) box in the graph so that parents come together and then flow to their children instead of both having lines to their respective children
	household="h$i"
	# Make sure the partners and the household are graphed at the same height
	echo -e "{rank=\"same\"\n\"$line\" $household \"$line2\"\n}"
	# Now tell DOT to draw a line from member1 to the household to member2
	echo "\"$line\" -> $household[weight=10]"
	echo " $household -> \"$line2\"[weight=10]"
	# Here we apply the settings for the household box, making it invisible
	echo "$household[shape=circle,label=\"\",height=0.01,width=0.01];"
    else #The person is a Child in this section
	siblings=""
	count=0
	# Continue down finding the persons siblings until we hit a new household
	while [[ "$raw" = "    "* ]]; do
	    # Parse the line so that it includes just the name of the person
	    line=${raw#    }
	    line=${line%% (*}
	    # Here we make a connector for the given child which will connect later to the household union of the parents. Doing this keeps the lines straight.
	    siblings="$siblings\"$household $i\" -> "
	    echo "\"$household $i\"[shape=circle,label=\"\",height=0.01,width=0.01];"
	    # Count the number of children
	    count=$(expr "$count" + 1)
	    # Draw a line from the connector generated before to the Child
	    echo "\"$household $i\" -> \"$line\"[weight=15]"	
	    # Move to the next line and get it's contents
	    i=$(expr "$i" + 1)
	    raw=$(pl "$i" "$1")
	done
	# Calculate to which connector we should connect the household
	n=$(expr "$i" - $(expr "$count" / 2) - 1)
	# Move back up one line. Since we finish the loop once we hit a new household and we move down one person before the loop restarts
	i=$(expr "$i" - 1)
	# If there are any kids, connect the household to the connector
	[ $count -gt 0 ] && echo "$household -> \"$household $n\""
	# Depending on your family, you may get better results if you change the weight from -1 to 1, this keeps siblings closer together.
	# Try this if your family members did not have many kids.
	echo "{rank=same; ${siblings%%-> }[weight=-1]}"
    fi

    # Move to the next line
    i=$(expr "$i" + 1)
done

# close the diagraph
echo "}"
