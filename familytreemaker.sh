	# Depending on your family, you may get better results if you change the weight from -1 to 1, this keeps siblings closer together.
	# Try this if your family members did not have many kids.
	echo "{rank=same; ${siblings%%-> }[weight=-1]}"
