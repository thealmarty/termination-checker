-- Sized typed built on top of LambdaPi
module TypeChecker where

import           Control.Monad.State
import           Evaluator
import           Prelude
import           Types

checkExpr :: Int -> Env -> Env -> Expr -> Value -> TypeCheck ()
checkExpr k rho gamma (Lam n e1) (VPi x va env t1) = do
  v_t1 <- eval (updateEnv env x (VGen k)) t1
  checkExpr (k + 1) (updateEnv rho n (VGen k)) (updateEnv gamma n va) e1 v_t1
checkExpr k rho gamma (Pi n t1 t2) VStar = do
  checkExpr k rho gamma t1 VStar
  v_t1 <- eval rho t1
  checkExpr (k + 1) (updateEnv rho n (VGen k)) (updateEnv gamma n v_t1) t2 VStar
checkExpr k rho gamma (Succ e2) VSize = checkExpr k rho gamma e2 VSize
checkExpr k rho gamma e v = do
  ev <- inferExpr k rho gamma e
  unless
    (ev == v)
    (error $
     "Type mismatched. \n" <> show e <> " \n (binder number " <> show k <>
     ") is of type \n" <>
     show ev <>
     "\n but the expected type is " <>
     show v)

inferExpr :: Int -> Env -> Env -> Expr -> TypeCheck Value
inferExpr _k _rho gamma (Var x) = return $ lookupEnv gamma x
inferExpr k rho gamma (App e1 e2) =
  case e2 of
    [] ->
      error $
      "inferExpr : App is applied to an empty list of expressions: " <> show e1 <>
      " is applied to " <>
      show e2 <>
      ", which is empty."
    [e] -> do
      v <- inferExpr k rho gamma e1
      case v of
        VPi x av env b -> do
          checkExpr k rho gamma e av
          v2 <- eval rho e
          eval (updateEnv env x v2) b
        _ ->
          error $
          "inferExpr : expected Pi with expression : " <> show e1 <> "," <>
          show v
    (hd:tl) -> inferExpr k rho gamma (App (App e1 [hd]) tl)
inferExpr _k _rho _gamma (Def n) = do
  sig <- get
  case lookupSig n sig of
    (DataSig _ _ _ tv) -> return tv
    (FunSig tv _ _) -> return tv
    (ConSig tv) ->
      error $
      "inferExpr: expecting type from data or function signature " <>
      show (Def n) <>
      " but found " <>
      show tv <>
      " from constructor signature. "
inferExpr _k _rho _gamma (Con n) = do
  sig <- get
  case lookupSig n sig of
    (ConSig tv) -> return tv
    (DataSig _ _ _ tv) ->
      error $
      "inferExpr: expecting type from data or function signature " <>
      show (Con n) <>
      " but found " <>
      show tv <>
      " from data type signature. "
    (FunSig tv _ _) ->
      error $
      "inferExpr: expecting type from data or function signature " <>
      show (Con n) <>
      " but found " <>
      show tv <>
      " from function signature. "
-- Pi, Lam, Size types, Star cannot be inferred
inferExpr _k _rho _gamma e =
  error $ "inferExpr: cannot infer the type of " <> show e
