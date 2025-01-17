module Signal
  ( (<~)
  , (~)
  , (~>)
  , Signal(..)
  , constant
  , dropRepeats
  , dropRepeats'
  , filter
  , filterMap
  , flatten
  , flattenArray
  , flippedMap
  , foldp
  , get
  , map2
  , map3
  , map4
  , map5
  , merge
  , mergeMany
  , runSignal
  , sampleOn
  , squigglyApply
  , squigglyMap
  , unsafeMerge
  , unsafeMergeMany
  , unwrap
  ) where

import Prelude

import Data.Foldable (fold, foldl, class Foldable)
import Data.Maybe (Maybe(..), fromMaybe, isJust)
import Effect (Effect)
import Effect.Unsafe (unsafePerformEffect)

foreign import data Signal :: Type -> Type

-- |Creates a signal with a constant value.
foreign import constant :: forall a. a -> Signal a

foreign import mapSig :: forall a b. (a -> b) -> Signal a -> Signal b
foreign import applySig :: forall a b. Signal (a -> b) -> Signal a -> Signal b

-- |Merge two signals, returning a new signal which will yield a value
-- |whenever either of the input signals yield. Its initial value will be
-- |that of the first signal.
foreign import merge :: forall a. Signal a -> Signal a -> Effect (Signal a)

unsafeMerge :: forall a. Signal a -> Signal a -> Signal a
unsafeMerge sig1 sig2 = unsafePerformEffect $ merge sig1 sig2

-- |Merge all signals inside a `Foldable`, returning a `Maybe` which will
-- |either contain the resulting signal, or `Nothing` if the `Foldable`
-- |was empty.
mergeMany :: forall f a. Foldable f => f (Signal a) -> Effect (Maybe (Signal a))
mergeMany sigs = foldl f (pure Nothing) sigs
  where
  f acc sig = do
    acc' <- acc
    case acc' of
      Nothing -> pure $ Just sig
      Just acc'' -> Just <$> merge sig acc''

unsafeMergeMany :: forall f a. Functor f => Foldable f => f (Signal a) -> Maybe (Signal a)
unsafeMergeMany sigs = foldl f Nothing sigs
  where
  f acc sig = Just $ fromMaybe sig $ unsafeMerge sig <$> acc

-- |Creates a past dependent signal. The function argument takes the value of
-- |the input signal, and the previous value of the output signal, to produce
-- |the new value of the output signal.
foreign import foldp :: forall a b. (a -> b -> b) -> b -> (Signal a) -> (Signal b)

-- |Creates a signal which yields the current value of the second signal every
-- |time the first signal yields.
foreign import sampleOn :: forall a b. (Signal a) -> (Signal b) -> (Signal b)

foreign import dropRepeatsImpl :: forall a. (a -> a -> Boolean) -> Signal a -> Signal a

-- |Create a signal which only yields values which aren't equal to the previous
-- |value of the input signal.
dropRepeats :: forall a. (Eq a) => Signal a -> Signal a
dropRepeats = dropRepeatsImpl (==)

-- |Create a signal which only yields values which aren't equal to the previous
-- |value of the input signal, using JavaScript's `!==` operator to determine
-- |disequality.
foreign import dropRepeatsByStrictInequality :: forall a. (Signal a) -> (Signal a)

dropRepeats' :: forall a. (Signal a) -> (Signal a)
dropRepeats' = dropRepeatsByStrictInequality

-- |Given a signal of effects with no return value, run each effect as it
-- |comes in.
foreign import runSignal :: Signal (Effect Unit) -> Effect Unit

-- |Takes a signal of effects of `a`, and produces an effect which returns a
-- |signal which will take each effect produced by the input signal, run it,
-- |and yield its returned value.
foreign import unwrap :: forall a. Signal (Effect a) -> Effect (Signal a)

-- |Gets the current value of the signal.
foreign import get :: forall a. Signal a -> Effect a

-- |Takes a signal and filters out yielded values for which the provided
-- |predicate function returns `false`.
foreign import filter :: forall a. (a -> Boolean) -> a -> (Signal a) -> (Signal a)

-- |Map a signal over a function which returns a `Maybe`, yielding only the
-- |values inside `Just`s, dropping the `Nothing`s.
filterMap :: forall a b. (a -> Maybe b) -> b -> Signal a -> Signal b
filterMap f def sig = (fromMaybe def) <$> filter isJust (Just def) (f <$> sig)

-- |Turns a signal of arrays of items into a signal of each item inside
-- |each array, in order.
-- |
-- |Like `flatten`, but faster.
foreign import flattenArray :: forall a. Signal (Array a) -> a -> Signal a

-- |Turns a signal of collections of items into a signal of each item inside
-- |each collection, in order.
flatten :: forall a f. Functor f => Foldable f => Signal (f a) -> a -> Signal a
flatten sig = flattenArray (sig ~> map (\i -> [ i ]) >>> fold)

instance functorSignal :: Functor Signal where
  map = mapSig

instance applySignal :: Apply Signal where
  apply = applySig

instance applicativeSignal :: Applicative Signal where
  pure = constant

instance semigroupSignal :: Monoid a => Semigroup (Signal a) where
  append = map2 append

instance monoidSignal :: Monoid a => Monoid (Signal a) where
  mempty = constant mempty

infixl 4 squigglyMap as <~
infixl 4 squigglyApply as ~
infixl 4 flippedMap as ~>

squigglyMap :: forall f a b. Functor f => (a -> b) -> f a -> f b
squigglyMap = map

squigglyApply :: forall f a b. Apply f => f (a -> b) -> f a -> f b
squigglyApply = apply

flippedMap :: forall f a b. Functor f => f a -> (a -> b) -> f b
flippedMap = flip map

map2 :: forall a b c. (a -> b -> c) -> Signal a -> Signal b -> Signal c
map2 f a b = f <~ a ~ b

map3 :: forall a b c d. (a -> b -> c -> d) -> Signal a -> Signal b -> Signal c -> Signal d
map3 f a b c = f <~ a ~ b ~ c

map4 :: forall a b c d e. (a -> b -> c -> d -> e) -> Signal a -> Signal b -> Signal c -> Signal d -> Signal e
map4 f a b c d = f <~ a ~ b ~ c ~ d

map5 :: forall a b c d e f. (a -> b -> c -> d -> e -> f) -> Signal a -> Signal b -> Signal c -> Signal d -> Signal e -> Signal f
map5 f a b c d e = f <~ a ~ b ~ c ~ d ~ e
