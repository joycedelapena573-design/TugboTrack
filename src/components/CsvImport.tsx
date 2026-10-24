/**
 * Reusable CSV import panel: paste a list or pick a .csv file from the device.
 * Parsing is delegated to the caller so each screen owns its own row shape.
 */
import * as DocumentPicker from 'expo-document-picker';
import { readAsStringAsync } from 'expo-file-system/legacy';
import { useState } from 'react';
import { StyleSheet, Text, TextInput, View } from 'react-native';

import { Button, Card } from '@/components/ui';
import { colors, radius, spacing } from '@/theme';

interface Props<T> {
  /** Shown above the paste box. */
  hint: string;
  /** Sample header + row so the user knows the expected format. */
  example: string;
  /** Turn raw CSV text into rows; throw to reject. */
  parse: (text: string) => T[];
  /** Apply the rows; return how many were actually added. */
  onImport: (rows: T[]) => number;
  onCancel: () => void;
}

export function CsvImport<T>({ hint, example, parse, onImport, onCancel }: Props<T>) {
  const [text, setText] = useState('');
  const [error, setError] = useState<string | null>(null);
  const [notice, setNotice] = useState<string | null>(null);

  const pickFile = async () => {
    setError(null);
    try {
      const result = await DocumentPicker.getDocumentAsync({
        type: ['text/csv', 'text/plain', '*/*'],
        copyToCacheDirectory: true,
        multiple: false,
      });
      if (result.canceled || !result.assets?.length) return;
      const asset = result.assets[0];
      // Web exposes a File object; native needs the file-system read.
      const contents = asset.file ? await asset.file.text() : await readAsStringAsync(asset.uri);
      setText(contents);
      setNotice(`Loaded ${asset.name}`);
    } catch {
      setError('Could not read that file. Try pasting the list instead.');
    }
  };

  const run = () => {
    setError(null);
    if (!text.trim()) {
      setError('Paste your list or choose a file first.');
      return;
    }
    try {
      const rows = parse(text);
      if (rows.length === 0) {
        setError('No rows found. Check the header row and try again.');
        return;
      }
      const added = onImport(rows);
      setNotice(added > 0 ? `Imported ${added} row${added === 1 ? '' : 's'}.` : 'Nothing new to import.');
      if (added > 0) setText('');
    } catch (e) {
      setError(e instanceof Error ? e.message : 'That file could not be read as CSV.');
    }
  };

  return (
    <Card>
      <Text style={styles.hint}>{hint}</Text>
      <Text style={styles.example}>{example}</Text>

      <TextInput
        multiline
        autoCapitalize="none"
        autoCorrect={false}
        placeholder={'name,section\nDela Cruz, Juan'}
        placeholderTextColor={colors.textMuted}
        value={text}
        onChangeText={(next) => {
          setText(next);
          setNotice(null);
        }}
        style={styles.area}
      />

      <View style={styles.actions}>
        <Button label="Choose file" variant="secondary" onPress={pickFile} style={styles.flex} />
        <Button label="Import" onPress={run} style={styles.flex} />
      </View>
      <Button label="Cancel" variant="ghost" onPress={onCancel} />

      {error ? <Text style={styles.error}>{error}</Text> : null}
      {notice ? <Text style={styles.notice}>{notice}</Text> : null}
    </Card>
  );
}

const styles = StyleSheet.create({
  hint: { fontSize: 14, color: colors.text, lineHeight: 20 },
  example: {
    fontSize: 12,
    color: colors.textMuted,
    fontFamily: 'monospace',
    backgroundColor: colors.surfaceAlt,
    borderRadius: radius.sm,
    padding: spacing.sm,
  },
  area: {
    minHeight: 130,
    borderWidth: 1,
    borderColor: colors.border,
    borderRadius: radius.md,
    padding: spacing.md,
    fontSize: 14,
    color: colors.text,
    textAlignVertical: 'top',
  },
  actions: { flexDirection: 'row', gap: spacing.sm },
  flex: { flex: 1 },
  error: { fontSize: 13, color: colors.danger, fontWeight: '600' },
  notice: { fontSize: 13, color: colors.success, fontWeight: '600' },
});