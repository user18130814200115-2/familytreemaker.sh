h

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
echo "digraph {	node [shape=box];edge [dir=none];"

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
	list="$list\"$id\"[label=\"$name\n$year\",style=filled,fillcolor=azure2];"
    # If they are female colour them orange
    elif [ "$sex" = "F" ]
    then
	list="$list\"$id\"[label=\"$name\n$year\",style=filled,fillcolor=bisque];"
    # Lasts, if the sex is not set, do not colour the box
    else
	list="$list\"$id\"[label=\"$name\n$year\"];"
    fi
    i=$(expr "$i" + 1)
done

# Sorting the list ensures that the line containing the most properties comes last.
# If you have a person appear twice (once as a child of their parents and once as parent of their own children, then you may only want to set the sex, birthyear and name once.
# To ensure that these properties do not get overridden, we have this sort line
echo "$list" | sed 's/;/;\n/g' | sort

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
	echo -e "{rank=same\n\"$line\" $household \"$line2\"\n}"
	# Now tell DOT to draw a line from member1 to the household to member2
	echo "\"$line\" -> $household -> \"$line2\""	
	# Here we apply the settings for the household box, making it invisible
	echo "$household[shape=circle,label=\"\",height=0.01,width=0.01];"
    else #The person is a Child in this section
	siblings=""
	# Continue down finding the persons siblings until we hit a new household
	while [[ "$raw" = "    "* ]]; do
	    # Parse the line so that it includes just the name of the person
	    line=${raw#    }
	    line=${line%% (*}
	    # Add the child to $string which will contain all the children
	    siblings="$siblings\"$line\" -> "
	    # Draw a line from the household generated before to the Child
	    echo "$household -> \"$line\""	
	    # Move to the next line and get it's contents
	    i=$(expr "$i" + 1)
	    raw=$(pl "$i" "$1")
	done
	# Move back up one line. Since we finish the loop once we hit a new household and we move down one person before the loop restarts
	i=$(expr "$i" - 1)
	# Draw invisible lines between all the siblings removing the arrow at the end
	# The grep statement is there so that this process is only done if the person has siblings, if we do not do this, DOT will get confused and erase the child
	echo -e "{rank=same\n${siblings%->*}[style=invis]\n}" | grep -B1 -A1 "\->"
    fi

    # Move to the next line
    i=$(expr "$i" + 1)
done

# close the diagraph
echo "}"
