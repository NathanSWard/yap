from testing import *

from yap.number import *


def test_float():
    var result = float.parse("3.14")
    var (output, input) = result.ok()

    assert_almost_equal(output, 3.14)
    assert_equal(input, "")
