Start 1,1--42
  AModule 1,1--41
    AMainClassdef 1,1--41
      AMainMethPropdef 1,1--41
        ABlockExpr 1,1--41
          AVardeclExpr 1,1--41
            TKwvar "var" 1,1--3
            TId "toto" 1,5--8
            AType 1,11--14
              TClassid "Toto" 1,11--14
            TAssign "=" 1,16
            ANewExpr 1,18--41
              TKwnew "new" 1,18--20
              AType 1,22--25
                TClassid "Toto" 1,22--25
              TId "toto" 1,27--30
              AParExprs 1,31--41
                TOpar "(" 1,31
                APlusExpr 1,32--40
                  ACallExpr 1,32--35
                    AImplicitSelfExpr 1,32
                    TId "toto" 1,32--35
                    AListExprs 1,35
                  ACallExpr 1,37--40
                    AImplicitSelfExpr 1,37
                    TId "toto" 1,37--40
                    AListExprs 1,40
                TCpar ")" 1,41
  EOF "" 1,42
