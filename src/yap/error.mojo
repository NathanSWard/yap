@fieldwise_init
@register_passable("trivial")
struct ErrKind(EqualityComparable, Representable, Stringable, Writable):
    alias BACKTRACK = Self(0)
    alias CUT = Self(1)

    var value: Int

    @always_inline
    fn __eq__(self, rhs: Self) -> Bool:
        return self.value == rhs.value

    @always_inline
    fn __ne__(self, rhs: Self) -> Bool:
        return self.value != rhs.value

    fn __repr__(self) -> String:
        return self.__str__()

    fn __str__(self) -> String:
        var string = String()
        self.write_to(string)
        return string^

    fn write_to[W: Writer](self, mut writer: W):
        if self == ErrKind.BACKTRACK:
            writer.write("ErrKind.BACKTRACK")
        elif self == ErrKind.CUT:
            writer.write("ErrKind.CUT")


struct Err(Copyable, Movable, Representable):
    var kind: ErrKind
    var input: StringSlice[ImmutableAnyOrigin]

    fn __init__[
        origin: ImmutableOrigin, //
    ](
        out self,
        *,
        input: StringSlice[origin],
        kind: ErrKind = ErrKind.BACKTRACK,
    ):
        self.kind = kind
        self.input = rebind[StringSlice[ImmutableAnyOrigin]](input)

    fn __is__(self, kind: ErrKind) -> Bool:
        return self.kind == kind

    fn __isnot__(self, kind: ErrKind) -> Bool:
        return not self is kind

    fn __repr__(self) -> String:
        return self.__str__()

    fn __str__(self) -> String:
        var string = String()
        self.write_to(string)
        return string^

    fn write_to[W: Writer](self, mut writer: W):
        writer.write("Err(kind=")
        self.kind.write_to(writer)
        writer.write(', input="')
        self.input.write_to(writer)
        writer.write('")')
