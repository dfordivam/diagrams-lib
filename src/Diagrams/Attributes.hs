{-# LANGUAGE DeriveDataTypeable         #-}
{-# LANGUAGE DeriveFunctor              #-}
{-# LANGUAGE ExistentialQuantification  #-}
{-# LANGUAGE FlexibleInstances          #-}
{-# LANGUAGE GeneralizedNewtypeDeriving #-}
{-# LANGUAGE LambdaCase                 #-}
{-# LANGUAGE MultiParamTypeClasses      #-}
{-# LANGUAGE ScopedTypeVariables        #-}
{-# LANGUAGE TypeFamilies               #-}
-----------------------------------------------------------------------------
-- |
-- Module      :  Diagrams.Attributes
-- Copyright   :  (c) 2011-2015 diagrams-lib team (see LICENSE)
-- License     :  BSD-style (see LICENSE)
-- Maintainer  :  diagrams-discuss@googlegroups.com
--
-- Diagrams may have /attributes/ which affect the way they are
-- rendered.  This module defines some common attributes; particular
-- backends may also define more backend-specific attributes.
--
-- Every attribute type must have a /semigroup/ structure, that is, an
-- associative binary operation for combining two attributes into one.
-- Unless otherwise noted, all the attributes defined here use the
-- 'Last' structure, that is, combining two attributes simply keeps
-- the second one and throws away the first.  This means that child
-- attributes always override parent attributes.
--
-----------------------------------------------------------------------------

module Diagrams.Attributes (
    -- ** Standard measures
    ultraThin, veryThin, thin, medium, thick, veryThick, ultraThick, none
  , tiny, verySmall, small, normal, large, veryLarge, huge

    -- ** Line width
  , LineWidth, getLineWidth, lineWidth, lineWidthM
  , lw, lwN, lwO, lwL, lwG

    -- ** Dashing
  , Dashing(..), DashingA, getDashing
  , dashing, dashingN, dashingO, dashingL, dashingG


  -- * Color
  -- $color

  , Color(..), SomeColor(..), someToAlpha

  -- ** Opacity
  , Opacity, getOpacity, opacity

  -- ** Converting colors
  , colorToSRGBA, colorToRGBA

  -- * Line stuff
  -- ** Cap style
  , LineCap(..), LineCapA, getLineCap, lineCap

  -- ** Join style
  , LineJoin(..), LineJoinA, getLineJoin, lineJoin

  -- ** Miter limit
  , LineMiterLimit(..), getLineMiterLimit, lineMiterLimit, lineMiterLimitA

  -- * Recommend optics

  , _Recommend
  , _Commit
  , _recommend
  , committed
  , isCommitted

  ) where

import           Control.Applicative
import           Control.Lens          hiding (none, over)
import           Data.Colour
import           Data.Colour.RGBSpace  (RGB (..))
import           Data.Colour.SRGB      (toSRGB)
import           Data.Default.Class
import           Data.Distributive
import           Data.Monoid.Recommend
import           Data.Semigroup
import           Data.Typeable

import           Diagrams.Core

------------------------------------------------------------------------
-- Standard measures
------------------------------------------------------------------------

none, ultraThin, veryThin, thin, medium, thick, veryThick, ultraThick,
  tiny, verySmall, small, normal, large, veryLarge, huge
  :: OrderedField n => Measure n
none       = output 0
ultraThin  = normalized 0.0005 `atLeast` output 0.5
veryThin   = normalized 0.001  `atLeast` output 0.5
thin       = normalized 0.002  `atLeast` output 0.5
medium     = normalized 0.004  `atLeast` output 0.5
thick      = normalized 0.0075 `atLeast` output 0.5
veryThick  = normalized 0.01   `atLeast` output 0.5
ultraThick = normalized 0.02   `atLeast` output 0.5

tiny      = normalized 0.01
verySmall = normalized 0.015
small     = normalized 0.023
normal    = normalized 0.035
large     = normalized 0.05
veryLarge = normalized 0.07
huge      = normalized 0.10

------------------------------------------------------------------------
-- Line width
------------------------------------------------------------------------

-- | Line widths specified on child nodes always override line widths
--   specified at parent nodes.
newtype LineWidth n = LineWidth (Last n)
  deriving (Typeable, Semigroup)

instance Rewrapped (LineWidth n) (LineWidth n')
instance Wrapped (LineWidth n) where
  type Unwrapped (LineWidth n) = n
  _Wrapped' = iso getLineWidth (LineWidth . Last)
  {-# INLINE _Wrapped' #-}

_LineWidth :: (Typeable n, OrderedField n) => Lens' (Style v n) (Measure n)
_LineWidth = atMAttr . mapping (mapping (_Wrapping (LineWidth . Last)))
           . anon medium (const False)

instance Typeable n => AttributeClass (LineWidth n)

type LineWidthM n = Measured n (LineWidth n)

instance OrderedField n => Default (LineWidthM n) where
  def = fmap (LineWidth . Last) medium

getLineWidth :: LineWidth n -> n
getLineWidth (LineWidth (Last w)) = w

-- | Set the line (stroke) width.
lineWidth :: (N a ~ n, HasStyle a, Typeable n) => Measure n -> a -> a
lineWidth = applyMAttr . fmap (LineWidth . Last)

-- | Apply a 'LineWidth' attribute.
lineWidthM :: (N a ~ n, HasStyle a, Typeable n) => LineWidthM n -> a -> a
lineWidthM = applyMAttr

-- | Default for 'lineWidth'.
lw :: (N a ~ n, HasStyle a, Typeable n) => Measure n -> a -> a
lw = lineWidth

-- | A convenient synonym for 'lineWidth (global w)'.
lwG :: (N a ~ n, HasStyle a, Typeable n, Num n) => n -> a -> a
lwG = lw . global

-- | A convenient synonym for 'lineWidth (normalized w)'.
lwN :: (N a ~ n, HasStyle a, Typeable n, Num n) => n -> a -> a
lwN = lw . normalized

-- | A convenient synonym for 'lineWidth (output w)'.
lwO :: (N a ~ n, HasStyle a, Typeable n, Num n) => n -> a -> a
lwO = lw . output

-- | A convenient sysnonym for 'lineWidth (local w)'.
lwL :: (N a ~ n, HasStyle a, Typeable n, Num n) => n -> a -> a
lwL = lw . local

------------------------------------------------------------------------
-- Dashing
------------------------------------------------------------------------

-- | Create lines that are dashing... er, dashed.
data Dashing n = Dashing [n] n
  deriving (Functor, Typeable)

newtype DashingA n = DashingA (Last (Dashing n))
  deriving (Functor, Typeable, Semigroup)

instance Rewrapped (DashingA n) (DashingA n')
instance Wrapped (DashingA n) where
  type Unwrapped (DashingA n) = Dashing n
  _Wrapped' = iso getDashing (DashingA . Last)
  {-# INLINE _Wrapped' #-}

_Dashing :: (Typeable n, OrderedField n)
         => Lens' (Style v n) (Maybe (Measured n (Dashing n)))
_Dashing = atMAttr . mapping (mapping (_Wrapping (DashingA . Last)))

instance Typeable n => AttributeClass (DashingA n)

getDashing :: DashingA n -> Dashing n
getDashing (DashingA (Last d)) = d

-- | Set the line dashing style.
dashing :: (N a ~ n, HasStyle a, Typeable n)
        => [Measure n]  -- ^ A list specifying alternate lengths of on
                        --   and off portions of the stroke.  The empty
                        --   list indicates no dashing.
        -> Measure n    -- ^ An offset into the dash pattern at which the
                        --   stroke should start.
        -> a -> a
dashing ds offs = applyMAttr . distribute $ DashingA (Last (Dashing ds offs))

-- | A convenient synonym for 'dashing (global w)'.
dashingG :: (N a ~ n, HasStyle a, Typeable n, Num n) => [n] -> n -> a -> a
dashingG w v = dashing (map global w) (global v)

-- | A convenient synonym for 'dashing (normalized w)'.
dashingN :: (N a ~ n, HasStyle a, Typeable n, Num n) => [n] -> n -> a -> a
dashingN w v = dashing (map normalized w) (normalized v)

-- | A convenient synonym for 'dashing (output w)'.
dashingO :: (N a ~ n, HasStyle a, Typeable n, Num n) => [n] -> n -> a -> a
dashingO w v = dashing (map output w) (output v)

-- | A convenient sysnonym for 'dashing (local w)'.
dashingL :: (N a ~ n, HasStyle a, Typeable n, Num n) => [n] -> n -> a -> a
dashingL w v = dashing (map local w) (local v)

------------------------------------------------------------------------
-- Color
------------------------------------------------------------------------

-- $color
-- Diagrams outsources all things color-related to Russell O\'Connor\'s
-- very nice colour package
-- (<http://hackage.haskell.org/package/colour>).  For starters, it
-- provides a large collection of standard color names.  However, it
-- also provides a rich set of combinators for combining and
-- manipulating colors; see its documentation for more information.

-- | The 'Color' type class encompasses color representations which
--   can be used by the Diagrams library.  Instances are provided for
--   both the 'Data.Colour.Colour' and 'Data.Colour.AlphaColour' types
--   from the "Data.Colour" library.
class Color c where
  -- | Convert a color to its standard representation, AlphaColour.
  toAlphaColour :: c -> AlphaColour Double

  -- | Convert from an AlphaColour Double.  Note that this direction
  --   may lose some information. For example, the instance for
  --   'Colour' drops the alpha channel.
  fromAlphaColour :: AlphaColour Double -> c

-- | An existential wrapper for instances of the 'Color' class.
data SomeColor = forall c. Color c => SomeColor c
  deriving Typeable

someToAlpha :: SomeColor -> AlphaColour Double
someToAlpha (SomeColor c) = toAlphaColour c

instance (Floating a, Real a) => Color (Colour a) where
  toAlphaColour   = opaque . colourConvert
  fromAlphaColour = colourConvert . (`over` black)

instance (Floating a, Real a) => Color (AlphaColour a) where
  toAlphaColour   = alphaColourConvert
  fromAlphaColour = alphaColourConvert

instance Color SomeColor where
  toAlphaColour (SomeColor c) = toAlphaColour c
  fromAlphaColour             = SomeColor

-- | Convert to sRGBA.
colorToSRGBA, colorToRGBA :: Color c => c -> (Double, Double, Double, Double)
colorToSRGBA col = (r, g, b, a)
  where
    c' = toAlphaColour col
    c = alphaToColour c'
    a = alphaChannel c'
    RGB r g b = toSRGB c

colorToRGBA = colorToSRGBA
{-# DEPRECATED colorToRGBA "Renamed to colorToSRGBA." #-}

alphaToColour :: (Floating a, Ord a, Fractional a) => AlphaColour a -> Colour a
alphaToColour ac | alphaChannel ac == 0 = ac `over` black
                 | otherwise = darken (recip (alphaChannel ac)) (ac `over` black)

------------------------------------------------------------------------
-- Opacity
------------------------------------------------------------------------

-- | Although the individual colors in a diagram can have
--   transparency, the opacity/transparency of a diagram as a whole
--   can be specified with the @Opacity@ attribute.  The opacity is a
--   value between 1 (completely opaque, the default) and 0
--   (completely transparent).  Opacity is multiplicative, that is,
--   @'opacity' o1 . 'opacity' o2 === 'opacity' (o1 * o2)@.  In other
--   words, for example, @opacity 0.8@ means \"decrease this diagram's
--   opacity to 80% of its previous opacity\".
newtype Opacity = Opacity (Product Double)
  deriving (Typeable, Semigroup)
instance AttributeClass Opacity

instance Rewrapped Opacity Opacity
instance Wrapped Opacity where
  type Unwrapped Opacity = Double
  _Wrapped' = iso getOpacity (Opacity . Product)
  {-# INLINE _Wrapped' #-}

_Opacity :: Lens' (Style v n) Double
_Opacity = atAttr . mapping (_Wrapping (Opacity . Product)) . non 1

getOpacity :: Opacity -> Double
getOpacity (Opacity (Product d)) = d

-- | Multiply the opacity (see 'Opacity') by the given value.  For
--   example, @opacity 0.8@ means \"decrease this diagram's opacity to
--   80% of its previous opacity\".
opacity :: HasStyle a => Double -> a -> a
opacity = applyAttr . Opacity . Product

------------------------------------------------------------------------
-- Line stuff
------------------------------------------------------------------------

-- line cap ------------------------------------------------------------

-- | What sort of shape should be placed at the endpoints of lines?
data LineCap = LineCapButt   -- ^ Lines end precisely at their endpoints.
             | LineCapRound  -- ^ Lines are capped with semicircles
                             --   centered on endpoints.
             | LineCapSquare -- ^ Lines are capped with a squares
                             --   centered on endpoints.
  deriving (Eq,Show,Typeable)

newtype LineCapA = LineCapA (Last LineCap)
  deriving (Typeable, Semigroup, Eq)
instance AttributeClass LineCapA

instance Rewrapped LineCapA LineCapA
instance Wrapped LineCapA where
  type Unwrapped LineCapA = LineCap
  _Wrapped' = iso getLineCap (LineCapA . Last)
  {-# INLINE _Wrapped' #-}

_LineCap :: Lens' (Style v n) LineCap
_LineCap = atAttr . mapping (_Wrapping (LineCapA . Last)) . non def

instance Default LineCap where
  def = LineCapButt

getLineCap :: LineCapA -> LineCap
getLineCap (LineCapA (Last c)) = c

-- | Set the line end cap attribute.
lineCap :: HasStyle a => LineCap -> a -> a
lineCap = applyAttr . LineCapA . Last

-- line join -----------------------------------------------------------

-- | How should the join points between line segments be drawn?
data LineJoin = LineJoinMiter    -- ^ Use a \"miter\" shape (whatever that is).
              | LineJoinRound    -- ^ Use rounded join points.
              | LineJoinBevel    -- ^ Use a \"bevel\" shape (whatever
                                 --   that is).  Are these...
                                 --   carpentry terms?
  deriving (Eq, Show, Typeable)

newtype LineJoinA = LineJoinA (Last LineJoin)
  deriving (Typeable, Semigroup, Eq)
instance AttributeClass LineJoinA

instance Rewrapped LineJoinA LineJoinA
instance Wrapped LineJoinA where
  type Unwrapped LineJoinA = LineJoin
  _Wrapped' = iso getLineJoin (LineJoinA . Last)
  {-# INLINE _Wrapped' #-}

_LineJoin :: Lens' (Style v n) LineJoin
_LineJoin = atAttr . mapping (_Wrapping (LineJoinA . Last)) . non def

instance Default LineJoin where
  def = LineJoinMiter

getLineJoin :: LineJoinA -> LineJoin
getLineJoin (LineJoinA (Last j)) = j

-- | Set the segment join style.
lineJoin :: HasStyle a => LineJoin -> a -> a
lineJoin = applyAttr . LineJoinA . Last

-- miter limit ---------------------------------------------------------

-- | Miter limit attribute affecting the 'LineJoinMiter' joins.
--   For some backends this value may have additional effects.
newtype LineMiterLimit = LineMiterLimit (Last Double)
  deriving (Typeable, Semigroup)
instance AttributeClass LineMiterLimit

instance Rewrapped LineMiterLimit LineMiterLimit
instance Wrapped LineMiterLimit where
  type Unwrapped LineMiterLimit = Double
  _Wrapped' = iso getLineMiterLimit (LineMiterLimit . Last)
  {-# INLINE _Wrapped' #-}

_LineMiterLimit :: Lens' (Style v n) Double
_LineMiterLimit = atAttr . mapping (_Wrapping (LineMiterLimit . Last)) . non 10

instance Default LineMiterLimit where
  def = LineMiterLimit (Last 10)

getLineMiterLimit :: LineMiterLimit -> Double
getLineMiterLimit (LineMiterLimit (Last l)) = l

-- | Set the miter limit for joins with 'LineJoinMiter'.
lineMiterLimit :: HasStyle a => Double -> a -> a
lineMiterLimit = applyAttr . LineMiterLimit . Last

-- | Apply a 'LineMiterLimit' attribute.
lineMiterLimitA :: HasStyle a => LineMiterLimit -> a -> a
lineMiterLimitA = applyAttr

------------------------------------------------------------------------
-- Recommend optics
------------------------------------------------------------------------

-- | Prism onto a 'Recommend'.
_Recommend :: Prism' (Recommend a) a
_Recommend = prism' Recommend $ \case (Recommend a) -> Just a; _ -> Nothing

-- | Prism onto a 'Commit'.
_Commit :: Prism' (Recommend a) a
_Commit = prism' Commit $ \case (Commit a) -> Just a; _ -> Nothing

-- | Lens onto the value inside either a 'Recommend' or 'Commit'. Unlike
--   'committed', this is a valid lens.
_recommend :: Lens (Recommend a) (Recommend b) a b
_recommend f (Recommend a) = Recommend <$> f a
_recommend f (Commit a)    = Commit <$> f a

-- | Lens onto weather something is commited or not.
isCommitted :: Lens' (Recommend a) Bool
isCommitted f r@(Recommend a) = f False <&> \b -> if b then Commit a else r
isCommitted f r@(Commit a)    = f True  <&> \b -> if b then r else Recommend a

-- | 'Commit' a value for any 'Recommend'. This is *not* a valid 'Iso'
--   because the resulting @Recommend b@ is always a 'Commit'. This is
--   useful because it means any 'Recommend' styles set with a lens will
--   not be accidentally overridden. If you want a valid lens onto a
--   recommend value use '_recommend'.
--
--   Other lenses that use this are labeled with a warning.
committed :: Iso (Recommend a) (Recommend b) a b
committed = iso getRecommend Commit

