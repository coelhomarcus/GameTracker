import { useEffect, useRef, useState } from 'react';
import { Animated, Pressable, StyleSheet, Text, View, type LayoutChangeEvent } from 'react-native';
import { colors, duration, fonts, opacity, radius, space, type } from '../../theme';

export interface Tab<T extends string> {
  value: T;
  label: string;
}

interface Props<T extends string> {
  tabs: readonly Tab<T>[];
  value: T;
  onChange: (value: T) => void;
  /**
   * `label` mede o texto e dimensiona o indicador por ele — é o que faz uma
   * barra de 4 abas não parecer quebrada ao lado de uma de 2.
   */
  indicator?: 'label' | 'full';
}

export function SegmentedTabs<T extends string>({ tabs, value, onChange, indicator = 'label' }: Props<T>) {
  const [labelWidths, setLabelWidths] = useState<Record<string, number>>({});
  const [barWidth, setBarWidth] = useState(0);

  const activeIndex = Math.max(0, tabs.findIndex((tab) => tab.value === value));
  const slot = barWidth / tabs.length;
  const width = indicator === 'full' ? slot : Math.min(labelWidths[tabs[activeIndex].value] ?? 0, slot);
  const left = slot * activeIndex + (slot - width) / 2;

  const offset = useRef(new Animated.Value(0)).current;
  useEffect(() => {
    if (!barWidth) return;
    Animated.timing(offset, {
      toValue: left,
      duration: duration.fast,
      useNativeDriver: true,
    }).start();
  }, [left, barWidth, offset]);

  function measure(tab: T) {
    return (event: LayoutChangeEvent) => {
      const measured = event.nativeEvent.layout.width;
      setLabelWidths((current) => (current[tab] === measured ? current : { ...current, [tab]: measured }));
    };
  }

  return (
    <View style={styles.bar} onLayout={(e) => setBarWidth(e.nativeEvent.layout.width)}>
      {tabs.map((tab) => {
        const active = tab.value === value;
        return (
          <Pressable
            key={tab.value}
            style={({ pressed }) => [styles.tab, pressed && { opacity: opacity.pressed }]}
            onPress={() => onChange(tab.value)}
            accessibilityRole="tab"
            accessibilityState={{ selected: active }}
            accessibilityLabel={tab.label}
          >
            <Text style={[styles.label, active && styles.labelActive]} onLayout={measure(tab.value)}>
              {tab.label}
            </Text>
          </Pressable>
        );
      })}

      {barWidth > 0 && width > 0 && (
        <Animated.View style={[styles.indicator, { width, transform: [{ translateX: offset }] }]} />
      )}
    </View>
  );
}

const styles = StyleSheet.create({
  bar: {
    flexDirection: 'row',
    borderBottomWidth: 1,
    borderBottomColor: colors.border,
  },
  tab: { flex: 1, alignItems: 'center', paddingVertical: space.md },
  // lineHeight um pouco maior que o de type.label (17): fonte customizada
  // corta a base de letras com descendente (g, j, p) em telas Android
  // quando a caixa da linha é justa demais.
  label: { ...type.label, lineHeight: 20, color: colors.textSecondary },
  labelActive: { ...type.label, lineHeight: 20, fontFamily: fonts.bold, color: colors.textPrimary },
  indicator: {
    position: 'absolute',
    bottom: 0,
    left: 0,
    height: 2,
    backgroundColor: colors.accent,
    borderRadius: radius.xs,
  },
});
