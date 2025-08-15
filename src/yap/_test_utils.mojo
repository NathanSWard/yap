struct Case(Movable & Copyable):
    var _msg: String

    fn __init__(out self, msg: String):
        self._msg = msg

    fn __enter__(self):
        pass

    fn __exit__(self):
        pass

    fn __exit__(self, error: Error) raises -> Bool:
        raise Error("Test Case [{}]:\n{}".format(self._msg, error.__str__()))
