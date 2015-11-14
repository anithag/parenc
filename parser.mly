%{
  open Ast
  open Printf
  open Lexing
%}

%token <int> INTEGER
%token <int> LOC
%token <string> VAR
%token <char> CHANNEL
%token PLUS UNDERSCORE LPAREN RPAREN LCURLY RCURLY COMMA SEQ COLON DOT EQUALS TRUE FALSE CALL
       IF THEN ELSE ENDIF LAMBDA EOF DEREF UPDATE SET ISUNSET  OUTPUT ASSIGN SKIP WHILE DO END
       INT BOOL COND FUNC REF LOW HIGH ERASE CHANNEL 

%type <Ast.program> program
%type <Ast.stmt> stmt
%type <Ast.exp> exp
%type <Ast.cndset> Uset

%start program
 
%%

Uset    : LCURLY RCURLY 		{VarSet.empty}
	 | LCURLY unsetcnd RCURLY	{VarSet.union $2 VarSet.empty }

unsetcnd : VAR 				{VarSet.add $1 VarSet.empty}
	 | VAR COMMA unsetcnd		{VarSet.add $1 $3}	
 
policy  : LOW				{Low}
        | HIGH				{High}
        | policy ERASE VAR  policy	{Erase($1, $3, $4)}

basetype  : INT				   {BtInt}
          | BOOL			   {BtBool}
          | COND			   {BtCond}
          | FUNC LPAREN policy COMMA Uset RPAREN {BtFunc($3, $5)}
	  | labeltype REF		   {BtRef($1)}

labeltype : basetype UNDERSCORE policy  { ($1, $3) }

vardecl   : LOC COLON labeltype   { VarLocMap.add (Mem $1) $3 VarLocMap.empty } 
          | VAR COLON labeltype	    { VarLocMap.add (Reg $1) $3 VarLocMap.empty }
	 
vardecllist: vardecl                { $1 }
	 |vardecl SEQ vardecllist   { VarLocMap.merge (fun key left right -> match left, right with
							| Some x, Some y -> None (* Error *)
							| None, right -> right
							| left, None  -> left
						      ) $1 $3 }
program: vardecllist stmt           {($1, $2)} 

stmt : IF bexp THEN stmt ELSE stmt ENDIF  { If($2, $4, $6) }
     | SKIP			    { Skip }
     | VAR ASSIGN exp		    { Assign($1, $3)  }
     | stmt SEQ stmt		    { Seq($1, $3)  }
     | WHILE bexp DO stmt   END     { While($2, $4) }
     | exp UPDATE exp 		    { Update($1, $3) }
     | OUTPUT LPAREN CHANNEL COMMA aexp RPAREN { Output($3, $5) }
     | CALL LPAREN exp RPAREN 	    { Call($3) }
     | SET LPAREN VAR RPAREN        { Set($3) }


exp : bexp 				{ $1 }
    | aexp 				{ $1 }
    | lexp                              { $1 }
    | DEREF exp				{ Deref($2) }

lexp : LPAREN LAMBDA LPAREN policy COMMA Uset RPAREN DOT stmt RPAREN UNDERSCORE policy 	{ Lam($4, $6, $12, $9) }
 
bexp: TRUE			   { True  }
    | FALSE                        { False }
    | aexp EQUALS aexp		   { Eq($1, $3) }
    | ISUNSET LPAREN VAR RPAREN    { Isunset($3) }

aexp: VAR                          { Var $1}
    | INTEGER                      { Constant($1) }
    | LOC			   { Loc($1) }
    | aexp PLUS aexp 		   { Plus($1, $3) }
loc : INTEGER			   { Loc $1}
