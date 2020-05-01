module Pattern where

import           Control.Monad.State (get)
import           Evaluator
import           Types

-- a substitution is a list of a partial mapping of generic values to values.
type Substitution = [(Int, Value)]

checkPatterns ::
     Int
  -> [(Int, (Expr, Value))]
  -> Substitution
  -> Env
  -> Env
  -> Value
  -> [Pattern]
  -> TypeCheck (Int, [(Int, (Expr, Value))], Substitution, Env, Env, Value)
checkPatterns k flex ins rho gamma v [] = return (k, flex, ins, rho, gamma, v)
checkPatterns k flex ins rho gamma v (p:pl) = do
  (k', flex', ins', rho', gamma', v') <- checkPattern k flex ins rho gamma v p
  checkPatterns k' flex' ins' rho' gamma' v' pl

{-
checkPattern k flex subst rho gamma v p = (k', flex', subst', rho', gamma', v')

Input :
  k     : next free generic value
  flex  : list of pairs (flexible variable, its dot(inaccessible) pattern + supposed type)
  subst : list of pairs (flexible variable, its valuation)
  rho   : binding of variables to values
  gamma : binding of variables to their types
  v     : type of the expression \ p -> t
  p     : the pattern to check
          (variable/constructor/inaccessible pattern)

Output
  updated versions of the inputs (after a pattern is checked)
-}
checkPattern ::
     Int
  -> [(Int, (Expr, Value))]
  -> Substitution
  -> Env
  -> Env
  -> Value
  -> Pattern
  -> TypeCheck (Int, [(Int, (Expr, Value))], Substitution, Env, Env, Value)
checkPattern k flex ins rho gamma (VPi x av env b) (VarP y) = do
  let gk = VGen k
  bv <- eval (updateEnv env x gk) b
  return (k + 1, flex, ins, updateEnv rho y gk, updateEnv gamma y av, bv)
checkPattern k flex ins rho gamma (VPi x av env b) (ConP n pl) = do
  sig <- get
  let ConSig vc = lookupSig n sig
  (k', flex', ins', rho', gamma', vc') <-
    checkPatterns k flex ins rho gamma vc pl
  let flexgen = map fst flex'
  subst <- inst k' flexgen vc' av
  let pv = patternToVal k (ConP n pl)
  vb <- eval (updateEnv env x pv) b
  ins'' <- compSubst ins' subst
  vb <- subsValue ins'' vb
  gamma' <- substEnv ins'' gamma'
  return (k', flex', ins'', rho', gamma', vb)
checkPattern k flex ins rho gamma (VPi x av env b) (DotP e) = do
  vb <- eval (updateEnv env x (VGen k)) b
  return (k + 1, (k, (e, av)) : flex, ins, rho, gamma, vb)
checkPattern _k _flex _ins _rho _gamma v _ = error $ "checkpattern: " <> show v

-- match v1 against v2 by unification , yielding a substition
inst :: Int -> [Int] -> Value -> Value -> TypeCheck Substitution
inst m flex v1 v2 =
  case (v1, v2) of
    (VGen k, _)
      | k `elem` flex -> do
        noc <- nonOccur m v1 v2 -- check for non-occurence
        if noc
          then return [(k, v2)]
          else error "inst: occurs check failed"
    (_, VGen k)
      | k `elem` flex -> do
        noc <- nonOccur m v2 v1
        if noc
          then return [(k, v1)]
          else error "inst: occurs check failed"
    (VApp (VDef d1) vl1, VApp (VDef d2) vl2)
      | d1 == d2 -> instList m flex vl1 vl2
    (VApp (VCon c1) vl1, VApp (VCon c2) vl2)
      | c1 == c2 -> instList m flex vl1 vl2
    (VSucc v1', VSucc v2') -> inst m flex v1' v2'
    (VSucc v, VInfty) -> inst m flex v VInfty
    -- _ -> do --TODO
    --   eqVal m v1 v2
    --   return []

instList :: Int -> [Int] -> [Value] -> [Value] -> TypeCheck Substitution
instList m flex [] [] = return []
instList m flex (v1:vl1) (v2:vl2) = do
  map <- inst m flex v1 v2
  vl1' <- mapM (substVal map) vl1
  vl2' <- mapM (substVal map) vl2
  map' <- instList m flex vl1' vl2'
  compSubst map map'

compSubst = undefined

substVal = undefined

subsValue = undefined

substEnv = undefined

patternToVal :: Int -> Pattern -> Value
patternToVal k p = fst (p2v k p)

-- turn a pattern into (value, k)
-- dot patterns get variables corresponding to their flexible generic value
p2v :: Int -> Pattern -> (Value, Int)
p2v k p =
  case p of
    VarP _p -> (VGen k, k + 1)
    ConP n [] -> (VCon n, k)
    ConP n pl ->
      let (vl, k') = ps2vs k pl
       in (VApp (VCon n) vl, k')
    SuccP _p ->
      let (v, k') = p2v k p
       in (VSucc v, k')
    DotP _e -> (VGen k, k + 1)

ps2vs :: Int -> [Pattern] -> ([Value], Int)
ps2vs k [] = ([], k)
ps2vs k (p:pl) =
  let (v, k') = p2v k p
      (vl, k'') = ps2vs k' pl
   in (v : vl, k'')

checkDot ::
     Int -> Env -> Env -> Substitution -> (Int, (Expr, Value)) -> TypeCheck ()
checkDot k rho gamma subst (i, (e, tv)) = undefined
