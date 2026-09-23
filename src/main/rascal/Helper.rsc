module Helper

@doc{
  Deliberately buggy for debugger testing: does not guard against b == 0,
  so calling divide(x, 0) throws a real runtime exception right here.
  Set a breakpoint on the line below and step Into divide() from
  Sanity::main to confirm the debugger correctly opens *this* file (not
  Sanity.rsc) at this exact line -- both when stepping normally and when
  the uncaught exception surfaces this as the failure site.
}
int divide(int a, int b) {
    return a / b;
}
