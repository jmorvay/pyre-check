(** Copyright (c) 2016-present, Facebook, Inc.

    This source code is licensed under the MIT license found in the
    LICENSE file in the root directory of this source tree. *)

open OUnit2
open IntegrationTest


let test_check_undefined_type _ =
  assert_default_type_errors
    {|
      def foo(x: Derp) -> Herp:
        pass
    |}
    [
      "Undefined type [11]: Type `Derp` is not defined.";
      "Undefined type [11]: Type `Herp` is not defined.";
    ];

  (* Don't crash when returning a bad type. *)
  assert_default_type_errors
    {|
      def foo(a: gurbage) -> None:
        return a
    |}
    [
      "Undefined type [11]: Type `gurbage` is not defined.";
    ];

  assert_default_type_errors
    {|
      def foo(a: gurbage) -> int:
        a = 1
        return a
    |}
    [
      "Undefined type [11]: Type `gurbage` is not defined.";
    ];

  assert_default_type_errors
    {|
      def foo(x: Derp, y: Herp) -> None:
        pass
    |}
    [
      "Undefined type [11]: Type `Derp` is not defined.";
      "Undefined type [11]: Type `Herp` is not defined.";
    ];
  assert_default_type_errors
    {|
      def foo(x: int) -> Herp:
        return x
    |}
    ["Undefined type [11]: Type `Herp` is not defined."];
  assert_default_type_errors
    {|
      def foo(x: typing.Union[Derp, Herp]) -> typing.List[Herp]:
        pass
    |}
    [
      "Undefined type [11]: Type `Derp` is not defined.";
      "Undefined type [11]: Type `Herp` is not defined.";
      "Undefined type [11]: Type `Herp` is not defined.";
    ];
  assert_default_type_errors
    {|
      def foo(x: Derp[int]) -> None:
        pass
    |}
    ["Undefined type [11]: Type `Derp` is not defined."];
  assert_default_type_errors
    {|
      def foo(x: Derp[int, str]) -> None:
        pass
    |}
    ["Undefined type [11]: Type `Derp` is not defined."];
  assert_default_type_errors
    {|
      def foo(x: typing.Optional[Derp[int]]) -> typing.List[Herp]:
        pass
    |}
    [
      "Undefined type [11]: Type `Derp` is not defined.";
      "Undefined type [11]: Type `Herp` is not defined.";
    ];
  assert_default_type_errors
    {|
      def foo(x: Optional) -> None:
        pass
    |}
    ["Undefined type [11]: Type `Optional` is not defined."];
  assert_default_type_errors
    {|
      def foo(x: Optional[Any]) -> None:
        pass
    |}
    [
      "Undefined type [11]: Type `Any` is not defined.";
      "Undefined type [11]: Type `Optional` is not defined.";
    ];
  assert_default_type_errors
    {|
      def foo(x: Dict) -> None:
        pass
    |}
    ["Undefined type [11]: Type `Dict` is not defined."];

  assert_default_type_errors
    {|
      def foo() -> None:
        x: undefined = 1
        return
    |}
    ["Undefined type [11]: Type `undefined` is not defined."];
  assert_default_type_errors
    {|
      def foo(x: Derp) -> None:
        y: undefined = 1
        return
    |}
    [
      "Undefined type [11]: Type `Derp` is not defined.";
      "Undefined type [11]: Type `undefined` is not defined.";
    ];

  assert_type_errors
    {|
      T = typing.TypeVar('T')
      def foo(x: T) -> typing.Union[str, T]:
        return x
    |}
    [];

  (* Ensure other errors are not missed when undefined type is thrown. *)
  assert_strict_type_errors
    {|
      class Bar:
          async def undefined(self, x: Derp) -> Derp:
              return x
      class Foo(Bar):
          def error(self) -> int:
              return None
          async def undefined(self, x: Herp) -> Herp:
              return x
    |}
    [
      "Undefined type [11]: Type `Derp` is not defined.";
      "Undefined type [11]: Type `Derp` is not defined.";
      "Incompatible return type [7]: Expected `int` but got `None`.";
      "Undefined type [11]: Type `Herp` is not defined.";
      "Undefined type [11]: Type `Herp` is not defined.";
    ];
  assert_strict_type_errors
    {|
      def foo() -> typing.Optional["Herp"]:
        return None
    |}
    ["Undefined type [11]: Type `Herp` is not defined."];

  assert_strict_type_errors
    {|
      class Foo:
        def __getitem__(self, other) -> typing.Any: ...

      def foo() -> Foo["Herp"]:
        return 1
    |}
    ["Undefined type [11]: Type `Herp` is not defined."]


let test_check_invalid_type _ =
  assert_type_errors
    {|
      MyType = int
      x: MyType = 1
    |}
    [];
  assert_type_errors
    {|
      # Type aliases cannot be annotated
      MyType: typing.Type[int] = int
      x: MyType = 1
    |}
    ["Invalid type [31]: Expression `MyType` is not a valid type."];
  assert_type_errors
    {|
      x: MyType = 1
    |}
    ["Undefined type [11]: Type `MyType` is not defined."];
  assert_type_errors
    {|
      MyType: int
      x: MyType = 1
    |}
    ["Invalid type [31]: Expression `MyType` is not a valid type."];
  assert_type_errors
    {|
      MyType = 1
      x: MyType = 1
    |}
    [
      "Invalid type [31]: Expression `MyType` is not a valid type."
    ];
  assert_type_errors
    {|
      MyType: typing.Any
      x: MyType = 1
    |}
    [];
  assert_type_errors
    {|
      MyType: typing.Any
      x: typing.List[MyType] = [1]
    |}
    []


let test_check_missing_type_parameters _ =
  assert_type_errors
    {|
      T = typing.TypeVar("_T")
      class C(typing.Generic[T]): ...
      def f(c: C) -> None:
        return None
    |}
    ["Missing type parameters [24]: Generic type `C` expects 1 type parameter."];
  assert_type_errors
    {|
      T = typing.TypeVar("_T")
      class C(typing.Generic[T]): ...
      def f(c: typing.List[C]) -> None:
        return None
    |}
    ["Missing type parameters [24]: Generic type `C` expects 1 type parameter."];
  assert_type_errors
    {|
      T = typing.TypeVar("_T")
      class C(typing.Generic[T]): ...
      def f() -> typing.List[C]:
        return []
    |}
    ["Missing type parameters [24]: Generic type `C` expects 1 type parameter."];
  assert_type_errors
    {|
      T = typing.TypeVar("_T")
      S = typing.TypeVar("_S")
      class C(typing.Generic[T, S]): ...
      def f() -> typing.List[C]:
        return []
    |}
    ["Missing type parameters [24]: Generic type `C` expects 2 type parameters."]


let test_check_analysis_failure _ =
  assert_type_errors
    {|
      def foo() -> Derp:
        pass

      def bar(x: int = foo()) -> int:
        return x
    |}
    [
      "Undefined type [11]: Type `Derp` is not defined.";
      "Incompatible variable type [9]: x is declared to have type `int` " ^
      "but is used as type `unknown`.";
    ];
  assert_type_errors
    {|
      def foo(x: int) -> None:
        pass

      def bar(x: Derp) -> None:
        test = foo( **x )
    |}
    [
      "Undefined type [11]: Type `Derp` is not defined.";
      "Invalid argument [32]: Keyword argument `x` has type `unknown` " ^
      "but must be a mapping with string keys.";
    ]


let test_check_immutable_annotations _ =
  assert_type_errors
    {|
      a: int = None
      def foobar() -> None:
          b: int = None
    |}
    [
      "Incompatible variable type [9]: a is declared to have type `int` " ^
      "but is used as type `None`.";
      "Incompatible variable type [9]: b is declared to have type `int` " ^
      "but is used as type `None`."
    ];
  assert_type_errors
    {|
      def foo() -> None:
        x: int = 1
        x = 'string'
    |}
    [
      "Incompatible variable type [9]: x is declared to have type `int` but is used as type `str`."
    ];
  assert_type_errors
    {|
      def f(x: int) -> None:
        x: str = int_to_str(x)
    |}
    [];
  assert_type_errors
    {|
    constant: int
    def foo() -> None:
      global constant
      constant = "hi"
    |}
    [
      "Incompatible variable type [9]: constant is declared to have type `int` but is used as " ^
      "type `str`.";
    ];

  assert_default_type_errors
    {|
      def expects_str(x: str) -> None:
        pass

      def foo(x: int, y: typing.Any) -> None:
        x = y
        expects_str(x)
    |}
    [
      "Incompatible parameter type [6]: " ^
      "Expected `str` for 1st anonymous parameter to call `expects_str` but got `int`."
    ];

  assert_type_errors
    {|
      def foo(x: str = 1) -> str:
        return x
    |}
    [
      "Incompatible variable type [9]: x is declared to have type `str` but is used as " ^
      "type `int`."
    ];

  assert_type_errors
    {|
      T = typing.TypeVar('T')
      def foo(x: T = 1) -> T:
        return x
    |}
    [];

  assert_type_errors
    {|
      T = typing.TypeVar('T', int, float)
      def foo(x: T = 1) -> T:
        return x
    |}
    [];

  assert_type_errors
    {|
      T = typing.TypeVar('T', int, float)
      def foo(x: T = "str") -> T:
        return x
    |}
    [
      "Incompatible variable type [9]: " ^
      "x is declared to have type `Variable[T <: [int, float]]` but is used as type `str`."
    ];

  assert_type_errors
    {|
      class B: pass
      class C(B): pass
      T = typing.TypeVar('T', bound=B)
      def foo(x: T = C()) -> T:
        return x
    |}
    [];

  assert_type_errors
    {|
      class O: pass
      class B: pass
      class C(B): pass
      T = typing.TypeVar('T', bound=B)
      def foo(x: T = O()) -> T:
        return x
    |}
    [
      "Incompatible variable type [9]: " ^
      "x is declared to have type `Variable[T (bound to B)]` but is used as type `O`."
    ];

  assert_type_errors
    {|
      def bar() -> typing.Any:
        ...
      def foo(x: str = bar()) -> str:
        return x
    |}
    [];

  assert_type_errors
    {|
      constant: int
      def foo() -> None:
        constant = "hi"
    |}
    [];

  assert_type_errors
    {|
      constant: int
      def foo() -> None:
        global constant
        constant: str
        constant = "hi"
    |}
    [];

  assert_type_errors
    {|
      constant: typing.Union[int, str]
      def foo() -> None:
        global constant
        constant = 1
    |}
    [];

  assert_type_errors
    {|
      constant: typing.Optional[int]
      def foo() -> int:
        if constant is not None:
          return constant
        return 0
    |}
    [];

  assert_type_errors
    {|
      constant: typing.Optional[str]
      def foo() -> int:
        if constant is not None:
          return constant
        return 0
    |}
    ["Incompatible return type [7]: Expected `int` but got `str`."];

  assert_type_errors
    {|
      constant: typing.Optional[int]
      def foo() -> int:
        if constant is not None:
          return 0
        return constant
    |}
    ["Incompatible return type [7]: Expected `int` but got `None`."];

  assert_type_errors
    {|
      constant
      def foo() -> None:
        global constant
        constant = 1
    |}
    [
      "Undefined name [18]: Global name `constant` is undefined.";
      "Missing global annotation [5]: Globally accessible variable `constant` has type `int` but " ^
      "no type is specified.";
    ];

  assert_type_errors
    {|
      constant: typing.Any
      def foo() -> None:
        global constant
        constant = 1
    |}
    [];

  assert_type_errors
    {|
      constant
      def foo() -> int:
        global constant
        constant = 1
        return constant
    |}
    [
      "Undefined name [18]: Global name `constant` is undefined.";
      "Missing global annotation [5]: Globally accessible variable `constant` has type `int` but " ^
      "no type is specified."
    ];

  assert_type_errors
    {|
      constant: int
      def foo(x: int) -> str:
        if x > 10:
          global constant
          constant: str
        return constant
    |}
    [
      "Incompatible return type [7]: Expected `str` but got `typing.Union[int, str]`."
    ];

  assert_type_errors
    {|
      def foo(x: int) -> None:
        x = "hi"
    |}
    [
      "Incompatible variable type [9]: x is declared to have type `int` but is used as " ^
      "type `str`."
    ];

  assert_type_errors
    {|
      def foo(x: typing.Optional[int]) -> None:
        x = 1
    |}
    [];

  assert_type_errors
    {|
      def foo(x: int) -> None:
        x: str
        x = "hi"
    |}
    [];

  assert_type_errors
    {|
      def foo() -> None:
        x = 1
        y: str
        y = x
        x = y
    |}
    [
      "Incompatible variable type [9]: y is declared to have type `str` but is used as " ^
      "type `int`."
    ];

  assert_type_errors
    {|
      def foo(any: typing.Any) -> None:
        x: int = any
    |}
    [
      "Missing parameter annotation [2]: Parameter `any` must have a type other than `Any`.";
      "Incompatible variable type [9]: x is declared to have type `int` " ^
      "but is used as type `typing.Any`.";
    ];

  assert_strict_type_errors
    {|
      def foo(any: typing.Any) -> None:
        x: int = any
    |}
    [
      "Missing parameter annotation [2]: Parameter `any` must have a type other than `Any`.";
    ];

  assert_type_errors
    {|
      def foo(x: int) -> None:
        if x > 10:
          y: int
        else:
          y: str

        y = "hi"
    |}
    [];

  assert_type_errors
    {|
      def foo(x: int) -> None:
        if x > 10:
          y: int
        else:
          y: str
        y = 1
    |}
    [];

  assert_type_errors
    {|
      class Foo():
        attribute
      def bar() -> None:
        foo = Foo()
        foo.attribute = 1
    |}
    [
      "Undefined name [18]: Global name `attribute` is undefined.";
    ];

  assert_type_errors
    {|
      constant
      def foo() -> None:
        global constant
        constant = 1
    |}
    [
      "Undefined name [18]: Global name `constant` is undefined.";
      "Missing global annotation [5]: Globally accessible variable `constant` has type `int` but " ^
      "no type is specified."
    ];

  assert_type_errors
    {|
      def foo() -> None:
        x: typing.Dict[str, typing.Any] = {}
        x = { 'a': 'b' }
    |}
    [];

  assert_default_type_errors
    {|
      constant = 1
      def foo() -> None:
        global constant
        constant = 1
    |}
    [];

  assert_type_errors
    {|
      constant
      def foo() -> None:
        global constant
        constant = 1
      def bar() -> None:
        global constant
        constant = "hi"
    |}
    [
      "Undefined name [18]: Global name `constant` is undefined.";
      "Missing global annotation [5]: Globally accessible variable `constant` has type `typing." ^
      "Union[int, str]` but no type is specified."
    ];

  assert_type_errors
    {|
      constant
      def foo() -> None:
        global constant
        constant = 1
      def bar() -> None:
        global constant
        constant = None
    |}
    [
      "Undefined name [18]: Global name `constant` is undefined.";
      "Missing global annotation [5]: Globally accessible variable `constant` has type `typing." ^
      "Optional[int]` but no type is specified."
    ];

  assert_type_errors
    {|
      constant
      def foo() -> None:
        global constant
        constant = 1
      def bar() -> None:
        global constant
        constant = 1.0
    |}
    [
      "Undefined name [18]: Global name `constant` is undefined.";
      "Missing global annotation [5]: Globally accessible variable `constant` has type `float` " ^
      "but no type is specified."
    ];

  assert_type_errors
    {|
      constant
      def foo() -> None:
        global constant
        constant = A()
      def bar() -> None:
        global constant
        constant = B()
    |}
    [
      "Undefined name [18]: Global name `constant` is undefined.";
      "Missing global annotation [5]: Globally accessible variable `constant` has type `A` but " ^
      "no type is specified."
    ];

  assert_type_errors
    {|
      constant
      class Foo():
        constant
      def foo() -> None:
        foo = Foo()
        foo.constant = 1
      def bar() -> None:
        global constant
        constant = "hi"
    |}
    [
      "Undefined name [18]: Global name `constant` is undefined.";
      "Missing global annotation [5]: Globally accessible variable `constant` has type `str` but " ^
      "no type is specified.";
    ];

  assert_type_errors
    {|
      class Foo():
        __slots__: typing.List[str] = ['name']
        def foo(self) -> str:
          return self.name
    |}
    [
      "Incompatible return type [7]: Expected `str` but got `unknown`.";
    ];

  assert_type_errors
    {|
      class Foo():
        __slots__: typing.List[str] = ['name', 'attribute']
        def foo(self) -> str:
          return self.name + self.attribute + self.constant
    |}
    [
      "Incompatible return type [7]: Expected `str` but got `unknown`.";
      "Undefined attribute [16]: `Foo` has no attribute `constant`.";
    ];

  assert_type_errors
    {|
      class Foo():
        __slots__: typing.List[str] = ['name']
        def foo(self) -> str:
          return self.name
        def __init__(self) -> None:
          self.name: int = 1
    |}
    ["Incompatible return type [7]: Expected `str` but got `int`."]


let test_check_refinement _ =
  assert_type_errors
    {|
      def takes_int(a: int) -> None: pass
      def foo() -> None:
        x: float
        x = 1
        takes_int(x)
        x = 1.0
    |}
    [];

  assert_type_errors
    {|
      def foo() -> None:
        l: typing.List[typing.Any] = []
        l = [1]
        l.append('asdf')
    |}
    [];

  assert_type_errors
    {|
      def foo() -> None:
        l: typing.List[int] = []
        l.append('a')
    |}
    ["Incompatible parameter type [6]: " ^
     "Expected `int` for 1st anonymous parameter to call `list.append` but got `str`."];

  assert_type_errors
    {|
      def foo() -> None:
        l: typing.List[int] = None
        l.append('a')
    |}
    [
      "Incompatible variable type [9]: l is declared to have type `typing.List[int]` " ^
      "but is used as type `None`.";
      "Incompatible parameter type [6]: " ^
      "Expected `int` for 1st anonymous parameter to call `list.append` but got `str`."
    ];

  assert_type_errors
    {|
      def foo(x: typing.Optional[int]) -> int:
        if not x:
          return 1
        return x
    |}
    [];
  assert_type_errors
    {|
      def foo(x: typing.Optional[int]) -> int:
        if not x:
          y = x
        return x
    |}
    ["Incompatible return type [7]: Expected `int` but got `typing.Optional[int]`."];
  assert_type_errors
    {|
      class A:
          a: typing.Optional[int] = None
          def foo(self) -> None:
              if self.a is None:
                  self.a = 5
    |}
    [];
  assert_type_errors
    {|
      class A:
          a: typing.Optional[int] = None
          def bar(self) -> int:
              if self.a is not None:
                  return self.a
              else:
                  return 1
    |}
    [];
  assert_type_errors
    {|
      def bar(x: typing.Optional[int]) -> None:
          if x and int_to_int(x) < 0:
              y = 1
    |}
    [];
  assert_type_errors
    {|
      def bar(input: typing.Optional[typing.Set[int]]) -> typing.Set[int]:
          if not input:
            input = set()
          return input
    |}
    [];

  assert_type_errors
    {|
      def bar(input: typing.Optional[int]) -> int:
          if not input:
            input = not_annotated()
          return input
    |}
    [
      "Incompatible variable type [9]: input is declared to have type `typing.Optional[int]` " ^
      "but is used as type `unknown`.";
      "Incompatible return type [7]: Expected `int` but got `unknown`.";
    ]


let () =
  "annotation">:::[
    "check_undefined_type">::test_check_undefined_type;
    "check_invalid_type">::test_check_invalid_type;
    "check_missing_type_parameters">::test_check_missing_type_parameters;
    "check_analysis_failure">::test_check_analysis_failure;
    "check_immutable_annotations">::test_check_immutable_annotations;
    "check_refinement">::test_check_refinement;
  ]
  |> Test.run
