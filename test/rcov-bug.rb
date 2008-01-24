# [5, 12, 12]

# Some rcov bugs.  The second 12 is a conservative guess at a potential
# function call in the regexp. It doesn't show up in traces. IS THIS RIGHT?
z = "
Now is the time
"

z =~ 
     /
      5
     /ix
