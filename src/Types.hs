{-# LANGUAGE FlexibleContexts #-}
{-# LANGUAGE DeriveFunctor #-}
{-# LANGUAGE TemplateHaskell #-}
{-# LANGUAGE RankNTypes #-}
{-# LANGUAGE GADTs #-}

module Types
  ( Tag(..)
  , Key(..)
  , ViewCreated(..)
  , ViewDestroyed(..)
  , OutputCreated(..)
  , OutputDestroyed(..)
  , OutputResolution(..)
  , WindowManager
  , StackSetChange
  , Actions
  , Action(..)
  ) where

import Control.Monad.Fix
import Data.Dependent.Map hiding (Key,split)
import Data.GADT.Compare.TH
import Data.Set hiding (split)
import Reflex
import Text.XkbCommon
import WLC

import StackSet (StackSet(..))

data Tag a where
     TKey :: Tag Key
     TViewCreated :: Tag ViewCreated
     TViewDestroyed :: Tag ViewDestroyed
     TOutputCreated :: Tag OutputCreated
     TOutputDestroyed :: Tag OutputDestroyed
     TOutputResolution :: Tag OutputResolution

data Key =
  Key WLCKeyState
      Keysym
      (Set WLCModifier)
  deriving (Show,Eq)

data ViewCreated =
  ViewCreated WLCViewPtr WLCOutputPtr
  deriving (Show,Eq,Ord)

data ViewDestroyed = ViewDestroyed WLCViewPtr deriving (Show,Eq,Ord)

data OutputCreated = OutputCreated WLCOutputPtr WLCSize deriving (Show,Eq,Ord)

data OutputDestroyed = OutputDestroyed WLCOutputPtr deriving (Show,Eq,Ord)

data OutputResolution = OutputResolution WLCOutputPtr WLCSize WLCSize deriving (Show,Eq,Ord)

type WindowManager t m = (Reflex t,MonadHold t m,MonadFix m) => Event t (DSum Tag) -> m (Event t (IO ()))
type StackSetChange i l a sid = StackSet i l a sid -> StackSet i l a sid

deriveGEq ''Tag
deriveGCompare ''Tag

data Action
  = InsertView WLCViewPtr
               WLCOutputPtr
  | FocusView WLCViewPtr
  | DestroyView WLCViewPtr
  | CreateOutput WLCOutputPtr WLCSize
  | DestroyOutput WLCOutputPtr
  | SpawnCommand String
  | FocusUp
  | FocusDown
  | SwapDown
  | SwapUp
  | NextOutput
  | PrevOutput
  | Split
  | MoveDown
  | MoveUp
  | ViewWorkspace String
  | ChangeResolution WLCOutputPtr WLCSize

type Actions = [Action]
