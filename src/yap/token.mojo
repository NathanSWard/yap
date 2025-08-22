from .parser import *
from .error import *
from .tuple import _TraitTuple

from bit import next_power_of_two

# --- char ---


@fieldwise_init
struct Char[char: StringSlice[ImmutableAnyOrigin]](
    Copyable & Movable & Parsable
):
    """Parser implementation for `char`."""

    alias Output = StringSlice[ImmutableAnyOrigin]

    fn parse(self, input: ParserInput) -> ParseResult[Self.Output]:
        constrained[
            char.char_length() == 1, "Char requres a single character"
        ]()

        alias char_ord = Codepoint.ord(char)

        if input and char_ord == Codepoint.ord(input[:1]):
            return (input[:1], input[1:])

        return Err(input=input)


alias char[char: StringSlice[mut=False]] = Parser(
    Char[rebind[StringSlice[ImmutableAnyOrigin]](char)]()
)


# --- tag ---


# TODO: eventually when trait extensions are, implement `Parser` for `String` directly
@fieldwise_init
struct Tag(Copyable & Movable & Parsable):
    """Parser implementation for `tag`."""

    alias Output = StringSlice[ImmutableAnyOrigin]

    var _tag: StringSlice[ImmutableAnyOrigin]

    fn parse(self, input: ParserInput) -> ParseResult[Self.Output]:
        if input.startswith(self._tag):
            return (self._tag, input[len(self._tag) :])
        else:
            return Err(input=input)


fn tag[origin: ImmutableOrigin, //](tag: StringSlice[origin]) -> Parser[Tag]:
    """Matches the provided tag string.

    Args:
        tag: The tag string to match.

    Retruns:
        A new `Tag` parser.
    """
    return Parser(Tag(rebind[StringSlice[ImmutableAnyOrigin]](tag)))


# --- tag_no_case ---


fn _create_ascii_caseless_codepoint_lookup_table() -> List[Codepoint]:
    var table = List(length=128, fill=Codepoint.ord("a"))
    for i in range(0, 128):
        var cp = Codepoint.from_u32(i).value()
        if cp.is_ascii_upper():
            # +32 turns an uppercase asii value to a lowercase one
            table[i] = Codepoint.from_u32(i + 32).value()
        else:
            table[i] = cp
    return table


alias _caseless_codepoint_lookup_table = _create_ascii_caseless_codepoint_lookup_table()


fn _codepoints_equal_no_case(a: Codepoint, b: Codepoint) -> Bool:
    if a.is_ascii() and b.is_ascii():
        return (
            _caseless_codepoint_lookup_table[a.to_u32()]
            == _caseless_codepoint_lookup_table[b.to_u32()]
        )
    else:
        return a == b


@fieldwise_init
struct TagNoCase(Copyable & Movable & Parsable):
    """Parser implementation for `tag_no_case`."""

    alias Output = StringSlice[ImmutableAnyOrigin]

    var _tag: StringSlice[ImmutableAnyOrigin]

    fn parse(self, input: ParserInput) -> ParseResult[Self.Output]:
        var tag_len = len(self._tag)
        if tag_len > len(input):
            return Err(input=input)
        else:
            for i in range(tag_len):
                var tag_codepoint = Codepoint.ord(self._tag[i])
                var input_codepoint = Codepoint.ord(input[i])
                if not _codepoints_equal_no_case(
                    tag_codepoint, input_codepoint
                ):
                    return Err(input=input)

        return (input[:tag_len], input[tag_len:])


fn tag_no_case[
    origin: ImmutableOrigin, //
](tag: StringSlice[origin]) -> Parser[TagNoCase]:
    """Todo."""

    return Parser(TagNoCase(rebind[StringSlice[ImmutableAnyOrigin]](tag)))


# --- any ---


@fieldwise_init
@register_passable("trivial")
struct Any(Copyable, Movable, Parsable):
    alias Output = StringSlice[ImmutableAnyOrigin]

    fn parse(self, input: ParserInput) -> ParseResult[Self.Output]:
        if input:
            return (input[:1], input[1:])
        else:
            return Err(input=input)


alias any = Parser(Any())


# --- take ---


@fieldwise_init
@register_passable("trivial")
struct TakeN(Copyable, Movable, Parsable):
    alias Output = StringSlice[ImmutableAnyOrigin]

    var _n: Int

    fn parse(self, input: ParserInput) -> ParseResult[Self.Output]:
        if len(input) >= self._n:
            return (input[: self._n], input[self._n :])
        else:
            return Err(input=input)


fn take_n(n: Int) -> Parser[TakeN]:
    """Takes the first `n` characters. Will error if the input is less than `n`

    Args:
        n: The number of characters to take from the input.

    Returns:
        A new `TakeN` parser.
    """
    return Parser(TakeN(n))


# --- take_(till/while) helper types ---


trait SliceIndexLocatable(Copyable & Movable):
    """A trait for locating `self` within a slice."""

    fn locate_slice_index(self, slice: StringSlice[ImmutableAnyOrigin]) -> Int:
        """Locate the index of `self` within the given `slice`.

        Args:
            slice: The slice to locate `self` within.

        Returns:
            The index where self was located, or `-1` if not found.

        By default, implementor should set `IsIndexLocatable` to `False`
        and have this function be `constrainted[False, "..."]()` to ensure
        parsers can correctly locate the value.
        """
        ...


trait ContainsCodepoint(Copyable & Movable):
    """A trait to determin if a codepoint is in a set of possible codepoints.

    Consider using the provided `Tokens`, `TokenRange`, or `TokenFn`.
    """

    fn contains_codepoint(self, codepoint: Codepoint) -> Bool:
        """Returns if this set contains the provided codepoint.

        Args:
            codepoint: The codepoint to check.

        Return:
            `True` if this type contains the codepoint.
        """
        ...


@fieldwise_init
@register_passable("trivial")
struct _TokenFn[f: fn (Codepoint) capturing -> Bool](
    Copyable & Movable & ContainsCodepoint
):
    fn contains_codepoint(self, input: Codepoint) -> Bool:
        return f(input)


alias token_fn[f: fn (Codepoint) capturing -> Bool] = _TokenFn[f]()
"""A wrapper around a function determining if a codepoint is found."""


@fieldwise_init
@register_passable("trivial")
struct _CodepointRange[
    start: StringSlice[mut=False], end: StringSlice[mut=False]
](Copyable & Movable & ContainsCodepoint):
    alias _has_valid_codepoint = constrained[
        start.char_length() == 1 and end.char_length() == 1,
        "CodepointRange requires start and end to be a single character.",
    ]()

    alias _start_codepoint = Codepoint.ord(start).to_u32()
    alias _end_codepoint = Codepoint.ord(end).to_u32()

    fn contains_codepoint(self, codepoint: Codepoint) -> Bool:
        return (
            Self._start_codepoint <= codepoint.to_u32() <= Self._end_codepoint
        )


alias CodepointRange[
    start: StringSlice[mut=False], end: StringSlice[mut=False]
] = _CodepointRange[start, end]()
"""A range of codepoint to look for.

This range is inclusive meaning: `start..=end`
"""


fn _generate_tokens_simd[
    *tokens: StringSlice[mut=False]
]() -> SIMD[DType.uint32, next_power_of_two(VariadicList(tokens).__len__())]:
    alias list = VariadicList(tokens)
    alias len = list.__len__()

    # we use UInt32.MAX here since that is not a valid codepoint value.
    var simd = SIMD[DType.uint32, next_power_of_two(len)](UInt32.MAX)

    @parameter
    for i in range(len):
        alias token = list[i]
        constrained[
            token.char_length() == 1,
            "Tokens requires its elements to have `char_len() == 1`",
        ]()
        simd[i] = Codepoint.ord(token).to_u32()

    return simd


@fieldwise_init
struct _Tokens[*tokens: StringSlice[mut=False]](
    Copyable & Movable & ContainsCodepoint
):
    fn contains_codepoint(self, codepoint: Codepoint) -> Bool:
        alias list = VariadicList(tokens)
        alias len = list.__len__()
        alias minimum_tokens_for_simd = 2

        @parameter
        if len <= minimum_tokens_for_simd:

            @parameter
            for token in list:
                constrained[
                    token.char_length() == 1,
                    "Tokens requires its elements to have `char_len() == 1`",
                ]()
                alias token_codepoint = Codepoint.ord(token)
                if token_codepoint == codepoint:
                    return True

            return False
        else:
            # TODO: check that len(_simd) <= simdwidthof[Codepoint]()
            alias simd = _generate_tokens_simd[*tokens]()
            return codepoint.to_u32() in simd


alias Tokens[*tokens: StringSlice[mut=False]] = _Tokens[*tokens]()
"""A list of individual codepoints to look for"""


struct TokenSet[*types: ContainsCodepoint](
    Copyable & Movable & ContainsCodepoint
):
    """A set of token predicates.

    This will use each child type to determine if a codepoint it found.

    You can use the provided: `Tokens`, `TokenRange`, or `TokenFn` types within this set.
    Or you can optionally implement your own by implementing the trait `ContainsCodepoint`.
    """

    alias _tuple = _TraitTuple[ContainsCodepoint, *types]
    var _elements: Self._tuple

    fn __init__(out self, var *elements: *types):
        self._elements = _TraitTuple[ContainsCodepoint, *types](
            storage=elements^
        )

    fn contains_codepoint(self, codepoint: Codepoint) -> Bool:
        @parameter
        for i in range(Self._tuple.__len__()):
            if self._elements[i].contains_codepoint(codepoint):
                return True
        return False


@register_passable("trivial")
struct Literal(Copyable & Movable & SliceIndexLocatable):
    """A string literal to search for."""

    var _literal: StringSlice[ImmutableAnyOrigin]

    fn __init__[
        origin: ImmutableOrigin, //
    ](out self, slice: StringSlice[origin]):
        self._literal = rebind[StringSlice[ImmutableAnyOrigin]](slice)

    fn locate_slice_index(self, slice: StringSlice[ImmutableAnyOrigin]) -> Int:
        return slice.find(self._literal)


fn _take_codepoint_impl[
    CodepointSetType: ContainsCodepoint, //,
    *,
    break_if_contains_codepoint: fn (Bool) capturing -> Bool,
    min: UInt,
    max: Optional[UInt],
](codepoints: CodepointSetType, input: ParserInput) -> ParseResult[
    StringSlice[ImmutableAnyOrigin]
]:
    @parameter
    if min > 0:
        if len(input) < min:
            return Err(input=input)

    var taken = 0
    for codepoint in input.codepoints():
        if break_if_contains_codepoint(
            codepoints.contains_codepoint(codepoint)
        ):
            break
        else:
            taken += 1

            @parameter
            if max:
                alias _max = Int(max.value())
                if taken == _max:
                    return (input[:_max], input[_max:])

    @parameter
    if min > 0:
        if taken < min:
            return Err(input=input)

    return (input[:taken], input[taken:])


# --- take_till_slice ---


@fieldwise_init
struct TakeTillSlice[
    SliceLocaterType: SliceIndexLocatable, min: UInt, max: Optional[UInt]
](Copyable, Movable, Parsable):
    alias Output = StringSlice[ImmutableAnyOrigin]

    var _locater: SliceLocaterType

    fn parse(self, input: ParserInput) -> ParseResult[Self.Output]:
        constrained[
            min <= max.or_else(UInt.MAX),
            "take_till_slice requires min <= max",
        ]()

        var index = self._locater.locate_slice_index(
            rebind[StringSlice[ImmutableAnyOrigin]](input)
        )

        @parameter
        if min == 0 and not max:
            if index < 0:
                return (input, Self.Output())
            else:
                return (input[:index], input[index:])
        elif not max:
            if index < min:
                return Err(input=input)
            else:
                return (input[:index], input[index:])
        else:
            if index < min:
                return Err(input=input)
            else:
                alias _max = Int(max.value())
                var n = index if index < _max else _max
                return (input[:n], input[n:])


fn take_till_slice[
    SliceLocaterType: SliceIndexLocatable, //,
    *,
    min: UInt = 0,
    max: Optional[UInt] = None,
](var locater: SliceLocaterType) -> Parser[
    TakeTillSlice[SliceLocaterType, min, max]
]:
    """Parser recognizing the longest `(min <= len <= max)` input slice till a slice is located.

    Parameters:
        SliceLocaterType: The type of the slice locater.
        min: The minimum length of the expected slice.
        max: The optional maximum length of the expected slice.

    Args:
        locater: The slice locater.

    Return:
        A new `TakeTillSlice` parser.
    """

    return Parser(TakeTillSlice[_, min, max](locater^))


fn take_till_slice[
    min: UInt = 0,
    max: Optional[UInt] = None,
](slice: StringSlice[mut=False]) -> Parser[TakeTillSlice[Literal, min, max]]:
    return take_till_slice[min=min, max=max](Literal(slice))


# --- take_till_codepoint ---


fn _invert_bool(b: Bool) -> Bool:
    return not b


fn _bool(b: Bool) -> Bool:
    return b


@fieldwise_init
struct TakeTillCodepoint[
    CodepointSetType: ContainsCodepoint, min: UInt, max: Optional[UInt]
](Copyable, Movable, Parsable):
    """Parser implementation for `take_till_codepoint`."""

    alias Output = StringSlice[ImmutableAnyOrigin]

    var _codepoint_set: CodepointSetType

    fn parse(self, input: ParserInput) -> ParseResult[Self.Output]:
        constrained[
            min <= max.or_else(UInt.MAX),
            "take_till_codepoint requires min <= max",
        ]()

        @parameter
        fn yes(b: Bool) -> Bool:
            return b

        return _take_codepoint_impl[
            break_if_contains_codepoint=yes, min=min, max=max
        ](self._codepoint_set, input)


fn take_till_codepoint[
    CodepointSetType: ContainsCodepoint, //,
    *,
    min: UInt,
    max: Optional[UInt] = None,
](var codepoints: CodepointSetType) -> Parser[
    TakeTillCodepoint[CodepointSetType, min, max]
]:
    """Parser recognizing the longest `(min <= len <= max)` input slice till a codepoint the set is found.

    Parameters:
        CodepointSetType: The type of the codepoint set.
        min: The minimum length of the expected slice.
        max: The optional maximum length of the expected slice.

    Args:
        codepoints: The codepoint set to check.

    Return:
        A new `TakeTillCodepoint` parser.
    """

    return Parser(TakeTillCodepoint[_, min, max](codepoints^))


# -- take_while ---


@fieldwise_init
struct TakeWhile[
    CodepointSetType: ContainsCodepoint, min: UInt, max: Optional[UInt]
](Copyable, Movable, Parsable):
    """Parser implementation for `take_while`."""

    alias Output = StringSlice[ImmutableAnyOrigin]

    var _codepoint_set: CodepointSetType

    fn parse(self, input: ParserInput) -> ParseResult[Self.Output]:
        constrained[
            min <= max.or_else(UInt.MAX),
            "take_while requires min <= max",
        ]()

        @parameter
        fn no(b: Bool) -> Bool:
            return not b

        return _take_codepoint_impl[
            break_if_contains_codepoint=no, min=min, max=max
        ](self._codepoint_set, input)


fn take_while[
    CodepointSetType: ContainsCodepoint, //, *, min: UInt
](var codepoints: CodepointSetType) -> Parser[
    TakeWhile[CodepointSetType, min, None]
]:
    """Parser recognizing the longest `(min <= len)` input slice that matches the provided codepoint set.

    Parameters:
        CodepointSetType: The type of the codepoint set.
        min: The minimum length of the expected slice.

    Args:
        codepoints: The codepoint set to check.

    Return:
        A new `TakeWhile` parser.
    """

    return Parser(TakeWhile[_, min, None](codepoints^))


fn take_while[
    CodepointSetType: ContainsCodepoint, //, *, min: UInt, max: UInt
](var codepoints: CodepointSetType) -> Parser[
    TakeWhile[CodepointSetType, min, Optional(max)]
]:
    """Parser recognizing the longest `(min <= len <= max)` input slice that matches the provided codepoint set.

    Parameters:
        CodepointSetType: The type of the codepoint set.
        min: The minimum length of the expected slice.
        max: The maximum length of the expected slice.

    Args:
        codepoints: The codepoint set to check.

    Return:
        A new `TakeWhile` parser.
    """

    return Parser(TakeWhile[_, min, Optional(max)](codepoints^))


# --- one_of ---


@fieldwise_init
struct OneOf[PredicateType: ContainsCodepoint](Copyable, Movable, Parsable):
    """Parser implementation for `one_of`."""

    alias Output = StringSlice[ImmutableAnyOrigin]

    var _predicate: PredicateType

    fn parse(self, input: ParserInput) -> ParseResult[Self.Output]:
        if input:
            var first_codepoint = Codepoint.ord(input[:1])
            if self._predicate.contains_codepoint(first_codepoint):
                return (input[:1], input[1:])

        return Err(input=rebind[Self.Output](input))


fn one_of[
    CodepointSetType: ContainsCodepoint, //
](var codepoints: CodepointSetType) -> Parser[OneOf[CodepointSetType]]:
    """Parser recognizing a single codepoint in the provided set.

    Parameters:
        CodepointSetType: The type of the codepoint set.

    Args:
        codepoints: The codepoint set to check.

    Return:
        A new `OneOf` parser.
    """

    return Parser(OneOf[_](codepoints^))


# --- none_of ---


@fieldwise_init
struct NoneOf[PredicateType: ContainsCodepoint](Copyable, Movable, Parsable):
    """Parser implementation for `none_of`."""

    alias Output = StringSlice[ImmutableAnyOrigin]

    var _predicate: PredicateType

    fn parse(self, input: ParserInput) -> ParseResult[Self.Output]:
        if input:
            var first_codepoint = Codepoint.ord(input[:1])
            if not self._predicate.contains_codepoint(first_codepoint):
                return (input[:1], input[1:])

        return Err(input=rebind[Self.Output](input))


fn none_of[
    CodepointSetType: ContainsCodepoint, //
](var codepoints: CodepointSetType) -> Parser[NoneOf[CodepointSetType]]:
    """Parser recognizing a single codepoint _NOT_ in the provided set.

    Parameters:
        CodepointSetType: The type of the codepoint set.

    Args:
        codepoints: The codepoint set to check.

    Return:
        A new `NoneOf` parser.
    """

    return Parser(NoneOf[_](codepoints^))


# --- rest ---


@fieldwise_init
@register_passable("trivial")
struct Rest(Copyable, Movable, Parsable):
    """Parser implementation for `rest`."""

    alias Output = StringSlice[ImmutableAnyOrigin]

    fn parse(self, input: ParserInput) -> ParseResult[Self.Output]:
        return (
            rebind[StringSlice[ImmutableAnyOrigin]](input),
            StringSlice[ImmutableAnyOrigin](),
        )


alias rest = Parser(Rest())
"""Parser that returns the remaining input (including an empty input)."""

# --- rest_len ---


@fieldwise_init
@register_passable("trivial")
struct RestLen(Copyable, Movable, Parsable):
    """Parser implementation for `rest_len`."""

    alias Output = Int

    fn parse(self, input: ParserInput) -> ParseResult[Self.Output]:
        return (len(input), rebind[StringSlice[ImmutableAnyOrigin]](input))


alias rest_len = Parser(RestLen())
"""Parser that returns the length of the remaining input.

This does _not_ consume the input.
"""
