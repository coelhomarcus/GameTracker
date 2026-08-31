import { Ionicons } from '@expo/vector-icons';
import { useState } from 'react';
import { Modal, Pressable, StyleSheet, Text, View } from 'react-native';
import { colors, forms, icon, opacity, radius, space, type } from '../../theme';
import { Calendar } from './Calendar';
import { IconButton } from './IconButton';

interface Props {
  label: string;
  value: Date | null;
  onChange: (value: Date | null) => void;
}

function formatDate(date: Date) {
  return date.toLocaleDateString('pt-BR');
}

/**
 * Calendário próprio num modal — substitui o DateTimePicker nativo do SO,
 * que no Android abre um diálogo do sistema difícil de estilizar e testar.
 * Sem "tocar fora fecha": mesmo padrão do GamePickerModal, fecha só pelo X
 * ou ao escolher um dia.
 */
export function DatePickerField({ label, value, onChange }: Props) {
  const [open, setOpen] = useState(false);

  return (
    <View>
      <Text style={forms.label}>{label}</Text>
      <Pressable
        style={({ pressed }) => [styles.row, pressed && { opacity: opacity.pressed }]}
        onPress={() => setOpen(true)}
      >
        <Ionicons name="calendar-outline" size={icon.md} color={colors.textSecondary} />
        <Text style={value ? styles.text : styles.placeholder}>{value ? formatDate(value) : 'Selecionar data'}</Text>
        {value && (
          <IconButton
            name="close-circle"
            size="md"
            onPress={() => onChange(null)}
            accessibilityLabel={`Limpar ${label.toLowerCase()}`}
          />
        )}
      </Pressable>

      <Modal visible={open} transparent animationType="fade" statusBarTranslucent onRequestClose={() => setOpen(false)}>
        <View style={styles.backdrop}>
          <View style={styles.card}>
            <View style={styles.cardHeader}>
              <Text style={styles.cardTitle}>{label}</Text>
              <IconButton name="close" onPress={() => setOpen(false)} accessibilityLabel="Fechar" />
            </View>
            <Calendar
              value={value}
              onChange={(date) => {
                onChange(date);
                setOpen(false);
              }}
            />
          </View>
        </View>
      </Modal>
    </View>
  );
}

const styles = StyleSheet.create({
  row: {
    ...forms.inputPill,
    flexDirection: 'row',
    alignItems: 'center',
    gap: space.sm,
  },
  text: { ...type.body, color: colors.textPrimary, flex: 1 },
  placeholder: { ...type.body, color: colors.textTertiary, flex: 1 },
  backdrop: { flex: 1, backgroundColor: colors.overlay, alignItems: 'center', justifyContent: 'center', padding: space.xl },
  card: { width: '100%', maxWidth: 360, backgroundColor: colors.surface, borderRadius: radius.lg, padding: space.lg },
  cardHeader: { flexDirection: 'row', alignItems: 'center', justifyContent: 'space-between', marginBottom: space.sm },
  cardTitle: { ...type.heading, color: colors.textPrimary },
});
