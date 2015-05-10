{-# LANGUAGE TemplateHaskell #-}
{-# LANGUAGE RecordWildCards #-}
{-# LANGUAGE DeriveFunctor #-}
{-# LANGUAGE DeriveFoldable #-}

module StackSet
  ( TreeZipper(..)
  , StackSet(..)
  , Workspace(..)
  , Screen(..)
  , deleteFromStackSet
  -- , viewWorkspace
  -- , focusUp
  -- , focusDown
  -- , swapUp
  -- , swapDown
  , modify
  , modifyWithOutput
  , createOutput
  , removeOutput
  -- , integrate
  -- , integrate'
  , delete'
  , workspace
  , current
  , visible
  , hidden
  , tag
  , mask
  , tree
  ) where


import Control.Lens
import Data.Maybe
import Foreign.C.Types
import Tree

delete' :: Eq a => a -> [a] -> ([a],Bool)
delete' a xs =
  case break (== a) xs of
    (_,[]) -> (xs,False)
    (us,_:vs) -> (us ++ vs,True)

data StackSet i l a sid =
  StackSet {_current :: !(Maybe (Screen i l a sid))
           ,_visible :: [Screen i l a sid]
           ,_hidden :: [Workspace i l a]}
  deriving (Show,Read,Eq)

data Workspace i l a =
  Workspace {_tag :: !i
            ,_mask :: !CUInt
            ,_tree :: TreeZipper l a}
  deriving (Show,Read,Eq)

data Screen i l a sid =
  Screen {_workspace :: !(Workspace i l a)
         ,_screen :: !sid}
  deriving (Show,Read,Eq)

makeLenses ''StackSet
makeLenses ''Workspace
makeLenses ''Screen

deleteFromStackSet :: Eq a => a -> StackSet i l a sid -> StackSet i l a sid
deleteFromStackSet v s = s & current . _Just . workspace %~ deleteFromWorkspace v
                           & visible . mapped . workspace %~ deleteFromWorkspace v
                           & hidden . mapped %~ deleteFromWorkspace v

deleteFromWorkspace :: Eq a => a -> Workspace i l a -> Workspace i l a
deleteFromWorkspace v ws = ws & tree %~ deleteFromTreeZipper v

deleteFromTreeZipper :: Eq a => a -> TreeZipper l a -> TreeZipper l a
deleteFromTreeZipper v tz = tz & focusT %~ deleteFromTree v
                               & parentsT . mapped . _1_3 . mapped %~ deleteFromTree v


_1_3 :: Traversal (a,c,a) (b,c,b) a b
_1_3 f (a,b,c) = (\x y -> (x,b,y)) <$> f a <*> f c


deleteFromTree :: Eq a => a -> Tree l a -> Tree l a
deleteFromTree v t = t & treeElements %~ (deleteFromListZipper v =<<)

deleteFromListZipper :: Eq a => a -> ListZipper (Either a (Tree l a)) -> Maybe (ListZipper (Either a (Tree l a)))
deleteFromListZipper v (ListZipper (Left v') [] [])
  | v == v' = Nothing
  | otherwise = return (ListZipper (Left v') [] [])
deleteFromListZipper v (ListZipper (Left v') (l:ls) [])
  | v == v' = return (ListZipper l ls [])
  | otherwise = return (ListZipper (Left v') (deleteFromList v ls) [])
deleteFromListZipper v (ListZipper (Left v') ls (r:rs))
  | v == v' = return (ListZipper r ls rs)
  | otherwise = return (ListZipper (Left v') (deleteFromList v ls) (deleteFromList v rs))
deleteFromListZipper v (ListZipper (Right t) ls rs) =
  return (ListZipper (Right (deleteFromTree v t))
                     (deleteFromList v ls)
                     (deleteFromList v rs))

deleteFromList :: Eq a => a -> [Either a (Tree l a)] -> [Either a (Tree l a)]
deleteFromList v = mapMaybe f
  where
    f (Left v')
       | v' == v = Nothing
       | otherwise = return (Left v')
    f (Right t) = return (Right (deleteFromTree v t))

-- deleteFromStackSet a (StackSet current visible hidden) =
--   StackSet (deleteFromScreen a <$> current)
--            (deleteFromScreen a <$> visible)
--            (deleteFromWorkspace a <$> hidden)

-- deleteFromScreen :: Eq a => a -> Screen i l a sid -> Screen i l a sid
-- deleteFromScreen a (Screen workspace sid) =
--   Screen (deleteFromWorkspace a workspace) sid

-- deleteFromWorkspace :: Eq a => a -> Workspace i l a -> Workspace i l a
-- deleteFromWorkspace view w =
--   w & tree %~
--   (deleteFromTreeZipper view)

-- deleteFromTreeZipper :: Eq l => l -> TreeZipper a l -> TreeZipper a l
-- deleteFromTreeZipper l (TreeZipper f ls rs ps)
--   | focusB = case focus' of
--                Just f' -> TreeZipper f' ls rs ps
--   where (focus',focusB) = deleteFromTree l f

-- deleteFromTree :: Eq l => l -> Tree a l -> (Maybe (Tree a l), Bool)
-- deleteFromTree l' (Leaf l)
--   | l == l' = (Nothing,True)
--   | otherwise = (Just (Leaf l),False)
-- deleteFromTree l' (Branch a Nothing) = (Just (Branch a Nothing),False)
-- -- deleteFromTree l' (Branch a (Just (ListZipper f [] [])))

-- deleteFromListZipper :: Eq a => a -> ListZipper a -> (Maybe (ListZipper a), Bool)
-- deleteFromListZipper a (ListZipper focus [] [])
--   | focus == a = (Nothing, True)
--   | otherwise = (Just (ListZipper focus [] []), False)
-- deleteFromListZipper a (ListZipper focus [] down) =
--   deleteFromListZipper
--     a
--     (ListZipper focus
--                 (reverse down)
--                 [])
-- deleteFromListZipper a (ListZipper focus (x:xs) down)
--   | focus == a = (Just (ListZipper x xs down),True)
--   | (up,True) <- delete' a (x:xs) = (Just (ListZipper focus up down),True)
--   | (down',True) <- delete' a down = (Just (ListZipper focus (x:xs) down'),True)
--   | otherwise = (Just (ListZipper focus (x:xs) down),False)


-- | try removing the supplied element from the stack, if it currently
-- focused use the next lower element
-- use supplied layout if there is none
-- deleteFromStack :: Eq l => a -> l -> TreeZipper a l -> (TreeZipper a l, Bool)
-- deleteFromStack a l' (TreeZipper (Leaf l) ls rs [])
--   | l' == l = (TreeZipper (Branch a Nothing) ls rs [], True)
--   | otherwise = (TreeZipper (Leaf l) ls rs [],False)
-- deleteFromStack a l' (TreeZipper (Leaf l) ls rs ((ls',a',rs'):ps)) =
-- deleteFromStack a (Stack focus [] [])
--   | focus == a = (Nothing, True)
--   | otherwise = (Just (Stack focus [] []), False)
-- deleteFromStack a (Stack focus [] down) =
--   deleteFromStack a
--                   (Stack focus (reverse down) [])
-- deleteFromStack a (Stack focus (x:xs) down)
--   | focus == a = (Just (Stack x xs down),True)
--   | (up,True) <- delete' a (x:xs) = (Just (Stack focus up down),True)
--   | (down',True) <- delete' a down = (Just (Stack focus (x:xs) down'),True)
--   | otherwise = (Just (Stack focus (x:xs) down),False)

-- viewWorkspace :: (Eq i,Eq sid)
--               => i -> StackSet i l a sid -> StackSet i l a sid
-- viewWorkspace _ s@(StackSet Nothing _ _) = s
-- viewWorkspace i s@(StackSet (Just currentScreen) visible' _)
--   | i == currentScreen ^. workspace . tag = s
--   | Just x <-
--      find (\x -> i == x ^. workspace . tag)
--           (s ^. visible) =
--     s & current .~ Just x
--       & visible .~ (currentScreen :
--                     deleteBy (equating (view screen)) x visible')
--   | Just x <-
--      find (\x -> i == x ^. tag)
--           (s ^. hidden) =
--     s & current .~ Just (currentScreen & workspace .~ x)
--       & hidden .~ (currentScreen ^. workspace :
--                    deleteBy (equating (view tag))
--                           x
--                           (s ^. hidden))
--   | otherwise = s

createOutput :: sid -> StackSet i l a sid -> StackSet i l a sid
createOutput _ (StackSet _ _ []) = error "No more workspaces available"
createOutput sid s@(StackSet Nothing _ (x:xs)) =
  s & current .~ Just (Screen x sid)
    & hidden .~ xs

createOutput sid s@(StackSet _ visible' (x:xs)) =
  s & visible .~ (Screen x sid) : visible'
    & hidden .~ xs

removeOutput :: Eq sid => sid -> StackSet i l a sid -> StackSet i l a sid
removeOutput sid s =
  StackSet current' visible' (hidden'' ++ hidden' ++ (s ^. hidden))
  where (visible',hidden') =
          deleteBySid sid (s ^. visible)
        (current',hidden'') =
          case (s ^. current) of
            Nothing -> (Nothing,[])
            Just screen'
              | screen' ^. screen == sid ->
                (Nothing,return $ screen' ^. workspace)
              | otherwise -> (Just screen',[])

deleteBySid :: Eq sid => sid -> [Screen i l a sid] -> ([Screen i l a sid],[Workspace i l a])
deleteBySid sid screens =
  break ((== sid) .
         (view screen))
        screens &
  _2 . traverse %~
  (view workspace)

withOutput :: (TreeZipper l a -> b) -> Screen i l a sid -> b
withOutput f s = f $ s ^. workspace . tree

modify :: (TreeZipper l a -> TreeZipper l a)
       -> StackSet i l a sid
       -> StackSet i l a sid
modify f s = s & current . _Just . workspace . tree %~ f

modifyWithOutput :: Eq sid
                 => (TreeZipper l a -> TreeZipper l a)
                 -> sid
                 -> StackSet i l a sid
                 -> StackSet i l a sid
modifyWithOutput f sid s =
  s & current . _Just %~
      (\cur -> modifyOutput f
                            (cur ^. screen)
                            cur)
    & visible %~map (modifyOutput f sid)

modifyOutput :: Eq sid
             => (TreeZipper l a -> TreeZipper l a)
             -> sid
             -> Screen i l a sid
             -> Screen i l a sid
modifyOutput f sid s
  | sid == s ^. screen =
    s & workspace . tree .~
    withOutput f s
  | otherwise = s

-- focusUp, focusDown, swapUp, swapDown :: StackSet i l a sid -> StackSet i l a sid
-- focusUp   = modify' focusUp'
-- focusDown = modify' focusDown'

-- swapUp    = modify' swapUp'
-- swapDown  = modify' (reverseStack . swapUp' . reverseStack)

-- swapUp' :: Stack a -> Stack a
-- swapUp'  (Stack t (l:ls) rs) = Stack t ls (l:rs)
-- swapUp'  (Stack t []     rs) = Stack t (reverse rs) []

-- focusUp', focusDown' :: Stack a -> Stack a
-- focusUp' (Stack t (l:ls) rs) = Stack l ls (t:rs)
-- focusUp' (Stack t []     rs) = Stack x xs [] where (x:xs) = reverse (t:rs)
-- focusDown'                   = reverseStack . focusUp' . reverseStack

-- reverseStack :: Stack a -> Stack a
-- reverseStack (Stack t ls rs) = Stack t rs ls

-- integrate :: Stack a -> [a]
-- integrate (Stack x l r) = reverse l ++ x : r

-- integrate' :: Maybe (Stack a) -> [a]
-- integrate' = maybe [] integrate
