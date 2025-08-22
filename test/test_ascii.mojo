from testing import *
from yap.ascii import *
from yap._test_utils import *


def test_whitespace():
    alias parser = take_while[min=0](
        TokenSet(
            Tokens["1", "3"],
            CodepointRange[start="a", end="z"],
        ),
    )
    var result = parser.parse("13cd1Za")
    var (output, input) = result.ok()

    assert_equal(output, "13cd1")
    assert_equal(input, "Za")


def test_escaped():
    alias parser = escaped[control="\\"](
        digit[min=1], one_of(Tokens["\\", '"', "n"])
    )

    var result = parser.parse('12\\"34;')
    var (output, input) = result.ok()

    assert_equal(output, '12\\"34')
    assert_equal(input, ";")
