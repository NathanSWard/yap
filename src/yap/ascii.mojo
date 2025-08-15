from .token import *
from .combinator import *


alias multispace[*, min: UInt = 0] = take_while[min=min](Tokens[" \t\r\n"])
"""TODO"""

alias space[*, min: UInt = 0] = take_while[min=min](Tokens[" \t"])
"""TODO"""

alias tab = tag("\t")
"""TODO"""

alias newline = tag("\n")
"""TODO"""

alias crlf = tag("\r\n")
"""TODO"""

alias line_ending = alt(tag("\n"), tag("\r\n"))
"""TODO"""
