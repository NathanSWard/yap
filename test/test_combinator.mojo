from testing import *
from yap.error import *
from yap.token import *
from yap.combinator import *
from yap._test_utils import *

# --- cut ---


def test_cut():
    alias parser = cut(fail)
    var result = parser.parse("yap")
    assert_true(result is ErrKind.CUT)
    assert_false(result is ErrKind.BACKTRACK)


# --- backtrack ---


def test_backtrack():
    # we have to cut it since by default errors are BACKTRACK
    alias parser = backtrack(cut(fail))
    var result = parser.parse("yap")
    assert_true(result is ErrKind.BACKTRACK)
    assert_false(result is ErrKind.CUT)
