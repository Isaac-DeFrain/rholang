// Structural type system - based on ASTs
require "../Syntax/rhosyntax.k"

module TYPE-SYNTAX
import RHOSYNTAX

// *******************
// *** Type Syntax ***
// *******************

syntax             Type ::= "#type(" Type ")"  // #type( t:Type ) => t
                          | InitialType        // Initializing syntax
                          | IntermediateType   // Intermediate syntax
                          | TerminalType       // Terminal syntax

// Recursive syntax for the type rewrites
//  Initial type
syntax      InitialType ::= "type[" Pat              "]"
                          | "type[" Leaf             "]"
                          | "type[" RepeatedBinds    "]"
                          | "type[" LinearBinds      "]"
                          | "type[" NamePats         "]"
                          | "type[" NameDeclarations "]"
                          | "type[" MatchCases       "]"

//  Intermediate type
syntax IntermediateType ::= "type[" String ";;" IntermediateType ";;" IntermediateType "]" [strict(2,3)]
                          | TerminalType
                          | InitialType

//  Terminal type
syntax     TerminalType ::= "type[" String ";;" Leaf             ";;" Leaf             "]"
                          | "type[" String ";;" TerminalType     ";;" TerminalType     "]"


//  Leaf
syntax             Leaf ::= Ground
                          | Var
                          | NameVar
                          | ProcVar
                          | "#truncate"

//  String
syntax           String ::= "toString(" Pat ")"
                          | "toString(" Method ")"

endmodule

module TYPE
import TYPE-SYNTAX
// For strictness
syntax          KResult ::= TerminalType

// *************
// *** #type ***
// *************

// #type( ) is strict and rewrites as the type of the input
rule #type( T:Type ) => T  [strict]


// *****************************
// *** Process type rewrites ***
// *****************************

// Ground terms
rule      type[ I:Int                ] => type[ "leaf" ;; "int"         ;; I ]
rule      type[ S:String             ] => type[ "leaf" ;; "string"      ;; S ]
rule      type[ uri( S:String )      ] => type[ "leaf" ;; "uri"         ;; S ]
rule      type[ unforgeable( I:Int ) ] => type[ "leaf" ;; "unforgeable" ;; I ]

// Boolean expressions
rule   type[ true                    ] => type[ "leaf"         ;; "bool"    ;; true            ]
rule   type[ false                   ] => type[ "leaf"         ;; "bool"    ;; false           ]
rule   type[ not B:Bool              ] => type[ "boolnot"      ;; type[B]   ;; type[#truncate] ]
rule   type[ I1:Int    <     I2:Int  ] => type[ "bool<"        ;; type[I1]  ;; type[I2]        ]
rule   type[ I1:Int    >     I2:Int  ] => type[ "bool>"        ;; type[I1]  ;; type[I2]        ]
rule   type[ I1:Int    <=    I2:Int  ] => type[ "bool<="       ;; type[I1]  ;; type[I2]        ]
rule   type[ I1:Int    >=    I2:Int  ] => type[ "bool>="       ;; type[I1]  ;; type[I2]        ]
rule   type[ P1:Proc matches P2:Proc ] => type[ "boolmatches"  ;; type[P1]  ;; type[P2]        ]
rule   type[ P1:Proc   ==    P2:Proc ] => type[ "bool=="       ;; type[P1]  ;; type[P2]        ]
rule   type[ P1:Proc   !=    P2:Proc ] => type[ "bool!="       ;; type[P1]  ;; type[P2]        ]
rule   type[ B1:Bool   and   B2:Bool ] => type[ "booland"      ;; type[B1]  ;; type[B2]        ]
rule   type[ B1:Bool   or    B2:Bool ] => type[ "boolor"       ;; type[B1]  ;; type[B2]        ]


// Collections
//  RhoLists
rule    type[ [ Hd:Proc , Tl:Procs ] ] => type[ "list" ;; type[ Hd ] ;; type[ [Tl] ]    ]
rule    type[ [ Sng:Proc           ] ] => type[ "list" ;; type[Sng]  ;; type[#truncate] ]

//  RhoTuples
rule type[ ( Hd:Proc , Md:Proc , Tl:Procs ) ] 
  => type[ "tuple" ;; type[Hd]  ;; type[ (Md,Tl) ] ]

rule type[ ( Hd:Proc , Tl:Proc ) ]
  => type[ "tuple" ;; type[Hd]  ;; type[ ( Tl  ) ] ]

rule type[ ( Sng:Proc ,) ]
  => type[ "tuple" ;; type[Sng] ;; type[#truncate] ]

//  RhoSets
rule type[ Set( Hd:Proc , Tl:Procs ) ] => type[ "set" ;; type[Hd]  ;; type[ Set(Tl) ] ]
rule type[ Set( Sng:Proc           ) ] => type[ "set" ;; type[Sng] ;; type[#truncate] ]

//  RhoMaps
rule type[{Hd:RhoKeyValuePair , Tl:RhoKeyValuePairs}] 
  => type[ "map" ;; type[{Hd}] ;; type[{Tl}] ]

rule type[{Key:Proc : Val:Proc }]
  => type[ "map" ;; type[Key]  ;; type[Val]  ]


// Process variables
rule                type[ PV:ProcVar ] => type[ "leaf" ;; "procvar" ;; PV ]


// Stopped process
rule                       type[ Nil ] => type[ "leaf" ;; "nil" ;; "Nil" ]


// Variable references
rule             type[ =  PV:ProcVar ] => type[ "varref" ;; type[PV] ;; type[#truncate] ]
rule             type[ =* NV:NameVar ] => type[ "varref" ;; type[NV] ;; type[#truncate] ]


// Evaluate
rule                  type[ * N:Name ] => type[ "eval" ;; type[N] ;; type[#truncate] ]


// Methods
rule type[ P:Proc . M:Method ( Hd:Proc , Tl:Procs ) ]
  => type[ "method" ;; type[Hd] ;; type[P:Proc . M:Method ( Tl:Procs )] ]

rule type[ P:Proc . M:Method ( Hd:Proc ) ]
  => type[ toString( M ) ;; type[P] ;; type[Hd] ]

rule type[ P:Proc . M:Method () ]
  => type[ toString( M ) ;; type[P] ;; type[#truncate] ]

// Arithmetic expressions
rule          type[ I1:Int *  I2:Int ] => type[ "mult"       ;; type[I1] ;; type[I2] ]
rule          type[ I1:Int /  I2:Int ] => type[ "div"        ;; type[I1] ;; type[I2] ]
rule          type[ I1:Int %% I2:Int ] => type[ "mod"        ;; type[I1] ;; type[I2] ]
rule          type[ I1:Int +  I2:Int ] => type[ "plus"       ;; type[I1] ;; type[I2] ]
rule          type[ I1:Int -  I2:Int ] => type[ "minus"      ;; type[I1] ;; type[I2] ]
rule          type[ I1:Int ++ I2:Int ] => type[ "plusplus"   ;; type[I1] ;; type[I2] ]
rule          type[ I1:Int -- I2:Int ] => type[ "minusminus" ;; type[I1] ;; type[I2] ]


// Sends
rule type[ Chan:Name !  (Msg:Proc)   ] => type[ "send"  ;; type[Chan] ;; type[Msg] ]
rule type[ Chan:Name !  Msg:RhoTuple ] => type[ "send"  ;; type[Chan] ;; type[Msg] ]
rule type[ Chan:Name !! (Msg:Proc)   ] => type[ "psend" ;; type[Chan] ;; type[Msg] ]
rule type[ Chan:Name !! Msg:RhoTuple ] => type[ "psend" ;; type[Chan] ;; type[Msg] ]


// Contracts **need to be given an alias which binds**
rule type[ contract Chan:Name ( Patns:NamePats ) = { Body:Proc } ]
  => type[ "contract" ;; type[ Patns <= Chan ] ;; type[ Body ] ]


// Listens
rule type[ for( LB:LinearBinds   ){ Body:Proc } ]
  => type[ "listen"  ;; type[ LB ] ;; type[ Body ] ]

rule type[ for( RB:RepeatedBinds ){ Body:Proc } ]
  => type[ "plisten" ;; type[ RB ] ;; type[ Body ] ]

rule type[ Hd:LinearBind ; Tl:LinearBinds ]
  => type[ "linearbinds" ;; type[Hd]    ;; type[Tl]   ]

rule type[ Patns:NamePats <- Chan:Name    ]
  => type[ "listen"      ;; type[Patns] ;; type[Chan] ]

rule type[ Patns:NamePats <! Chan:Name    ]
  => type[ "peek"        ;; type[Patns] ;; type[Chan] ]

rule type[ RB:RepeatedBind ; RBs:RepeatedBinds ]
  => type[ "repeatedbinds" ;; type[RB] ;; type[RBs] ]

rule type[ Patns:NamePats <= Chan:Name ]
  => type[ "plisten" ;; type[Patns] ;; type[Chan] ]


// Name Patterns
rule  type[ Hd:NamePat , Tl:NamePats ] => type[ "namepats" ;; type[Hd] ;; type[Tl] ]


// Matches
rule type[ match P:Proc { MC:MatchCases } ]
  => type[ "match"      ;; type[P]    ;; type[MC] ]

rule type[ Hd:MatchCase Tl:MatchCases ]
  => type[ "matchcases" ;; type[Hd]   ;; type[Tl] ]

rule type[ (Patn => { Body }):MatchCase ] 
  => type[ "matchcase"  ;; type[Patn] ;; type[Body] ]


// Bundles
rule        type[ bundle+ { P:Proc } ] => type[ "bundle+" ;; type[P] ;; type[#truncate] ]
rule        type[ bundle- { P:Proc } ] => type[ "bundle-" ;; type[P] ;; type[#truncate] ]
rule        type[ bundle0 { P:Proc } ] => type[ "bundle0" ;; type[P] ;; type[#truncate] ]
rule        type[ bundle  { P:Proc } ] => type[ "bundle"  ;; type[P] ;; type[#truncate] ]

// Conditionals
//  If ... then ...
rule      type[ if ( B:Bool ) P:Proc ] => type[ "if" ;; type[B] ;; type[P] ]

//  If ... then ... else ...
rule type[ if ( B:Bool ) PTrue:Proc else PFalse:Proc ]
  => type[ "ifelse" ;; type[B] ;; type[ "ifelseprocs" ;; type[PTrue] ;; type[PFalse] ] ]


// New
rule type[ new N:NameDeclarations in { Body:Proc} ]
  => type[ "new" ;; type[N] ;; type[Body] ]

rule type[ Hd:NameDeclaration, Tl:NameDeclarations ]
  => type[ "namedeclarations"   ;; type[Hd] ;; type[Tl] ]

rule type[ NV:NameVar ( U:Uri ) ]
  => type[ "urinamedeclaration" ;; type[NV] ;; type[U] ]


// Parallel
rule   type[ P1:ProcPat | P2:ProcPat ] => type[ "par" ;; type[P1] ;; type[P2] ]


// **************************
// *** Name type rewrites ***
// **************************

// Quoted processes
rule                   type[ @P:Proc ] => type[ "quote" ;; type[P]   ;; type[#truncate] ]

// Name variables
rule                type[ NV:NameVar ] => type[ "leaf"  ;; "namevar" ;; NV ]


// *****************************
// *** Pattern type rewrites ***
// *****************************

// Collection Pat
//  RhoListPat Multiple
rule type[ [Hd1:ProcPat, Hd:ProcPats, ... Tl:ProcVar] ]
  => type[ "rholistpathead" ;; type[Hd1] ;; type[ [Hd,  ... Tl] ] ]

//  RhoListPat Single
rule type[ [Hd:ProcPat, ... Tl:ProcVar] ]
  => type[ "rholistpat" ;; type[Hd] ;; type[Tl] ]

//  RhoSetPat Multiple
rule type[ Set(Hd1:ProcPat, Hd:ProcPats, ... Tl:ProcVar) ]
  => type[ "rhosetpathead"  ;; type[Hd1] ;; type[Set(Hd, ... Tl)] ]

//  RhoSetPat Single
rule type[ Set(Hd:ProcPat, ... Tl:ProcVar) ]
  => type[ "rhosetpat"  ;; type[Hd] ;; type[Tl] ]


// SimpleType
rule             type[ ST:SimpleType ] => type[ "simpletype" ;; type[toString(ST)] ;; type[#truncate] ]


// Logical negation
rule            type[ ~ PPat:ProcPat ] => type[ "logicalnegate" ;; type[PPat] ;; type[#truncate] ]

// Logical "and"
rule type[ PPat1:ProcPat /\ PPat2:ProcPat ]
  => type[ "logicaland" ;; type[PPat1] ;; type[PPat2] ]

// Logical "or"
rule type[ PPat1:ProcPat \/ PPat2:ProcPat ]
  => type[ "logicalor"  ;; type[PPat1] ;; type[PPat2] ]


// ************
// *** Misc ***
// ************

// #truncate
rule                 type[ #truncate ] => type[ "leaf" ;; "truncate" ;; #truncate ]

endmodule
