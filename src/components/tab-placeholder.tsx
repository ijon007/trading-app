import { useMinimizeOnScroll } from 'expo-glass-tabs';
import { Text } from 'react-native';
import Animated from 'react-native-reanimated';
import { withUniwind } from 'uniwind';

import { GlassPad } from '@/components/glass-pad';

const ScrollView = withUniwind(Animated.ScrollView);

export function TabPlaceholder({ title }: { title: string }) {
  const onScroll = useMinimizeOnScroll();

  return (
    <ScrollView
      className="flex-1 bg-background"
      contentContainerClassName="grow items-center justify-center px-6"
      onScroll={onScroll}
      scrollEventThrottle={16}>
      <GlassPad>
        <Text className="text-xl font-semibold text-foreground">{title}</Text>
      </GlassPad>
    </ScrollView>
  );
}
