--  The wlroots binding layer.
--
--  Everything in this subtree is a direct, auditable transcription of what
--  wlroots and libwayland actually export, and nothing more. Rules that hold
--  for every package here:
--
--    * Opaque C objects are System.Address. No tagged types, no controlled
--      types, no smart handles. Wrap and unwrap explicitly at the boundary.
--
--    * Every imported subprogram carries an Assumption comment stating what
--      the pointer must be, what state it must be in, and what the library
--      does not define. Those comments are the specification; the C library is
--      not going to raise an exception for a violated precondition.
--
--    * Only symbols that are actually exported may be imported. A plausible
--      name that is not exported fails at link time and looks like a toolchain
--      fault. `static inline` helpers have to be reimplemented; the one that
--      matters here is wl_signal_add, in Iris.Wlroots.Listeners.
--
--    * Struct mirrors are proven against C `offsetof` output before they are
--      trusted, because a wrong offset corrupts state silently instead of
--      crashing. The ground truth program is tests/c_layout_ground_truth.c.
--
--    * Callbacks must be library-level subprograms. Ada rejects `'Access` of a
--      nested subprogram against a library-level access type, so callback
--      state lives at library level alongside the handlers.

package Iris.Wlroots is
   pragma Pure;

end Iris.Wlroots;
