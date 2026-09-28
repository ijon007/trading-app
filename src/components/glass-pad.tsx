import { GlassView, type GlassStyle, isLiquidGlassAvailable } from 'expo-glass-effect';
import { type ReactNode } from 'react';
import { withUniwind } from 'uniwind';

const StyledGlass = withUniwind(GlassView);

const hasLiquidGlass = isLiquidGlassAvailable();

type GlassPadProps = {
  children: ReactNode;
  className?: string;
  glassEffectStyle?: GlassStyle;
};

export function GlassPad({ children, className, glassEffectStyle = 'regular' }: GlassPadProps) {
  const surface = hasLiquidGlass ? '' : 'border border-hairline bg-glass';

  return (
    <StyledGlass
      colorScheme="auto"
      glassEffectStyle={glassEffectStyle}
      className={`items-center justify-center overflow-hidden rounded-2xl px-6 py-4 ${surface} ${className ?? ''}`}>
      {children}
    </StyledGlass>
  );
}
