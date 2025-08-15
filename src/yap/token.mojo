from .parser import *
from .error import *
from builtin.variadics import VariadicList
from collections.optional import OptionalReg


# --- tag ---

@fieldwise_init
struct Tag(Copyable & Movable & Parsable):
    alias Output = StaticString

    var _tag: StaticString

    fn parse[
        origin: ImmutableOrigin, //
    ](self, input: StringSlice[origin]) -> ParseResult[Self.Output]:
           if input.startswith(self._tag):  
                return (self._tag, input[len(self._tag) :])
            else:
                return Err(input=input)


fn tag(tag: StaticString) -> Parser[Tag]:
    return Parser(Tag(tag))


# --- any ---


@fieldwise_init
@register_passable("trivial")
struct Any(Copyable, Movable, Parsable):
    alias Output = StringSlice[ImmutableAnyOrigin]

    fn parse[
        origin: ImmutableOrigin, //
    ](self, input: StringSlice[origin]) -> ParseResult[Self.Output]:
        if input:
            return (input[0:1], input[1:])
        else:
            return Err(input=input)


alias any = Parser(Any())


# --- take ---


@fieldwise_init
@register_passable("trivial")
struct TakeN(Copyable, Movable, Parsable):
    alias Output = StringSlice[ImmutableAnyOrigin]

    var _n: Int

    fn parse[
        origin: ImmutableOrigin, //
    ](self, input: StringSlice[origin]) -> ParseResult[Self.Output]:
        if len(input) >= self._n:
            return (input[: self._n], input[self._n :])
        else:
            return Err(input=input)


fn take_n(n: Int) -> Parser[TakeN]:
    return Parser(TakeN(n))


# --- take_till ---

trait ContainsToken:
    fn contains[origin: ImmutableOrigin, //](self, input: StringSlice[origin]) -> Bool:
        ...

@register_passable("trivial")
struct TokenRange(Copyable & Movable):
    var start: StringSlice[ImmutableAnyOrigin]
    var end: StringSlice[ImmutableAnyOrigin]

    fn __init__[origin_start: ImmutableOrigin, origin_end: ImmutableOrigin, //](
        out self, *, start: StringSlice[origin_start], end: StringSlice[origin_end]
    ):
        self.start = rebind[StringSlice[ImmutableAnyOrigin]](start)
        self.end = rebind[StringSlice[ImmutableAnyOrigin]](end)

@register_passable("trivial")
struct TokenSetValue(Copyable & Movable):
    var _lit: OptionalReg[StringSlice[ImmutableAnyOrigin]]
    var _range: OptionalReg[TokenRange]

    @implicit
    fn __init__[origin: ImmutableOrigin](out self, slice: StringSlice[origin]):
        self._lit = rebind[StringSlice[ImmutableAnyOrigin]](slice)
        self._range = None

    @implicit
    fn __init__(out self, lit: StringLiteral):
        self._lit = rebind[StringSlice[ImmutableAnyOrigin]](lit.as_string_slice())
        self._range = None

    @implicit
    fn __init__(out self, token_range: TokenRange):
        self._lit = None
        self._range = token_range

    fn contains[origin: ImmutableOrigin, //](self, input: StringSlice[origin]) -> Bool:
        var codepoint = ord(input)
        if self._range:
            var token_range = self._range.value()
            return ord(token_range.start) <= codepoint and codepoint <= ord(token_range.end)
        else:
            var lit = self._lit.value()
            return input == lit

struct _TokenSet[*values: TokenSetValue]:
    alias _tokens_type = VariadicList(values)

    fn __init__(out self):
        pass

    fn contains[origin: ImmutableOrigin, //](self, input: StringSlice[origin]) -> Bool:
        @parameter
        for token in Self._tokens_type:
            if token.contains(input):
                return True
        return False
            

alias TokenSet[*values: TokenSetValue] = _TokenSet[*values]()


trait Findable(Copyable, Movable):
    fn find_in[input_origin: ImmutableOrigin, //](self, input: StringSlice[input_origin]) -> Int:
        ...


@fieldwise_init
@register_passable("trivial")
struct _Tokens[origin: ImmutableOrigin, //, tokens: StringSlice[origin]](Findable, ContainsCodepoint):
    fn find_in[input_origin: ImmutableOrigin, //](self, input: StringSlice[input_origin]) -> Int:
        @parameter    
        for token in tokens.codepoint_slices():
            var index = input.find(token)
            if index != -1:
                return index
        return -1

    fn contains_codepoint(self, codepoint: Codepoint) -> Bool:
        @parameter
        for token in tokens.codepoint_slices():
            if Codepoint.ord(token) == codepoint:
                return True
        return False

alias Tokens[origin: ImmutableOrigin, //, tokens: StringSlice[origin]] = _Tokens[tokens]()


@fieldwise_init
struct Literal[origin: ImmutableOrigin, //](Findable):
    var _literal: StringSlice[origin]

    fn find_in[input_origin: ImmutableOrigin, //](self, input: StringSlice[input_origin]) -> Int:
        return input.find(self._literal)


@fieldwise_init
struct TakeTill[Find: Findable, min: UInt, max: Optional[UInt]](
    Copyable, Movable, Parsable
):
    alias Output = StringSlice[ImmutableAnyOrigin]

    var _findable: Find

    fn parse[
        origin: ImmutableOrigin, //
    ](self, input: StringSlice[origin]) -> ParseResult[Self.Output]:
        constrained[min <= max.or_else(UInt.MAX), "take_till required min <= max"]()

        var index = self._findable.find_in(input)

        @parameter
        if min == 0 and not max:
            if index == -1:
                return (input, StringSlice[ImmutableAnyOrigin]())
            else:
                return (input[:index], input[index:])
        elif not max:
            if index < min:
                return Err(input=input)
            else:
                return (input[:index], input[index:])
        else:
            alias _max = max.value()
            if index < min or len(input) - index > _max:
                return Err(input=input)
            else:
                return (input[:index], input[index:])


fn take_till[
    Find: Findable, //,
    *,
    min: UInt = 0
](var find: Find) -> Parser[TakeTill[Find, min, None]]:
    return Parser(TakeTill[Find, min, None](find^))

fn take_till[
    Find: Findable, //, *,
    max: UInt,
    min: UInt = 0,
](var find: Find) -> Parser[TakeTill[Find, min, Optional(max)]]:
    return Parser(TakeTill[Find, min, Optional(max)](find^))


# -- take_while ---

trait Tokenable:
    ...

alias Set[*tokens: Tokenable] = VariadicPack[False, ImmutableAnyOrigin, Tokenable, *tokens]

trait ContainsCodepoint(Copyable & Movable):
    fn contains_codepoint(self, codepoint: Codepoint) -> Bool:
        ...

@fieldwise_init
struct TakeWhile[PredicateType: ContainsCodepoint, min: UInt, max: Optional[UInt]](
    Copyable, Movable, Parsable
):
    var _predicate: PredicateType

    alias Output = StringSlice[ImmutableAnyOrigin]

    fn parse[
        origin: ImmutableOrigin, //
    ](self, input: StringSlice[origin]) -> ParseResult[Self.Output]:
        # TODO: optimization: if "predicate" is a single character, we can probably do an `rfind`

        var taken = 0
        for codepoint in input.codepoint_slices():
            if not self._predicate.contains_codepoint(Codepoint.ord(codepoint)):
                break
            else:
                taken += 1

                @parameter
                if max:
                    alias _max = max.value()
                    if taken > _max:
                        return Err(input=input) 

        @parameter
        if min > 0:
            if taken < min:
                return Err(input=input)
                
        return (input[:taken], input[taken:])
        

fn take_while[PredicateType: ContainsCodepoint, //, *, min: UInt](var predicate: PredicateType) -> Parser[TakeWhile[PredicateType, min, None]]:
    return Parser(TakeWhile[_, min, None](predicate^))

fn take_while[PredicateType: ContainsCodepoint, //, *, min: UInt, max: UInt](var predicate: PredicateType) -> Parser[TakeWhile[PredicateType, min, Optional(max)]]:
    return Parser(TakeWhile[_, min, Optional(max)](predicate^))

fn take_while[PredicateType: ContainsCodepoint, //, *, min: UInt, max: Optional[UInt] = None](var predicate: PredicateType) -> Parser[TakeWhile[PredicateType, min, max]]:
    return Parser(TakeWhile[_, min, max](predicate^))

# --- one_of ---


@fieldwise_init
@register_passable("trivial")
struct OneOf(Copyable, Movable, Parsable):
    alias Output = StringSlice[ImmutableAnyOrigin]

    var _tokens: StaticString

    fn parse[
        origin: ImmutableOrigin, //
    ](self, input: StringSlice[origin]) -> ParseResult[Self.Output]:
        if input:
            first = input[0:1]
            for token in self._tokens.codepoint_slices():
                if token == first:
                    return (first, input[1:])

        return Err(input=rebind[StringSlice[ImmutableAnyOrigin]](input))


fn one_of(tokens: StaticString) -> Parser[OneOf]:
    return Parser(OneOf(tokens))


# --- none_of ---


@fieldwise_init
@register_passable("trivial")
struct NoneOf[tokens_origin: ImmutableOrigin](Copyable, Movable, Parsable):
    alias Output = StringSlice[ImmutableAnyOrigin]

    var _tokens: StringSlice[tokens_origin]

    fn parse[
        origin: ImmutableOrigin, //
    ](self, input: StringSlice[origin]) -> ParseResult[Self.Output]:
        if not input:
            return Err(input=rebind[StringSlice[ImmutableAnyOrigin]](input))

        first = input[0:1]
        for token in self._tokens.codepoint_slices():
            if token == first:
                return Err(input=rebind[StringSlice[ImmutableAnyOrigin]](input))

        return ParseResult((rebind[StringSlice[ImmutableAnyOrigin]](first), rebind[StringSlice[ImmutableAnyOrigin]](input[1:])))


fn none_of[origin: ImmutableOrigin, //](tokens: StringSlice[origin]) -> Parser[NoneOf[origin]]:
    return Parser(NoneOf(tokens))


# --- rest ---


@fieldwise_init
@register_passable("trivial")
struct Rest(Copyable, Movable, Parsable):
    alias Output = StringSlice[ImmutableAnyOrigin]

    fn parse[
        origin: ImmutableOrigin, //
    ](self, input: StringSlice[origin]) -> ParseResult[Self.Output]:
        return ParseResult((rebind[StringSlice[ImmutableAnyOrigin]](input), StringSlice[ImmutableAnyOrigin]()))


alias rest = Parser(Rest())


# --- rest_len ---


@fieldwise_init
@register_passable("trivial")
struct RestLen(Copyable, Movable, Parsable):
    alias Output = Int

    fn parse[
        origin: ImmutableOrigin, //
    ](self, input: StringSlice[origin]) -> ParseResult[Self.Output]:
        return ParseResult((len(input), rebind[StringSlice[ImmutableAnyOrigin]](input)))


alias rest_len = Parser(RestLen())
