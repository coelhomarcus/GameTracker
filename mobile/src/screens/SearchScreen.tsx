import { useNavigation } from '@react-navigation/native';
import type { NativeStackNavigationProp } from '@react-navigation/native-stack';
import { useQuery } from '@tanstack/react-query';
import { useEffect, useState } from 'react';
import { ActivityIndicator, FlatList, Image, Pressable, StyleSheet, Text, TextInput, View } from 'react-native';
import * as gamesApi from '../api/games';
import { getApiErrorMessage } from '../lib/apiError';
import type { RootStackParamList } from '../navigation/types';
import type { IgdbSearchResult } from '../types/models';

export default function SearchScreen() {
  const navigation = useNavigation<NativeStackNavigationProp<RootStackParamList>>();
  const [input, setInput] = useState('');
  const [term, setTerm] = useState('');

  useEffect(() => {
    const timeout = setTimeout(() => setTerm(input.trim()), 400);
    return () => clearTimeout(timeout);
  }, [input]);

  const query = useQuery({
    queryKey: ['games', 'search', term],
    queryFn: () => gamesApi.searchGames(term),
    enabled: term.length >= 2,
  });

  function renderItem({ item }: { item: IgdbSearchResult }) {
    return (
      <Pressable style={styles.row} onPress={() => navigation.navigate('GameDetail', item)}>
        {item.coverUrl ? (
          <Image source={{ uri: item.coverUrl }} style={styles.cover} />
        ) : (
          <View style={[styles.cover, styles.coverPlaceholder]} />
        )}
        <View style={styles.rowInfo}>
          <Text style={styles.rowTitle}>{item.name}</Text>
          <Text style={styles.rowSubtitle}>{item.platforms.slice(0, 3).join(', ') || 'Plataforma desconhecida'}</Text>
        </View>
      </Pressable>
    );
  }

  return (
    <View style={styles.container}>
      <TextInput
        style={styles.input}
        placeholder="Buscar jogo..."
        value={input}
        onChangeText={setInput}
        autoCapitalize="none"
      />

      {query.isFetching && <ActivityIndicator style={styles.spinner} />}
      {query.isError && <Text style={styles.error}>{getApiErrorMessage(query.error, 'Falha na busca')}</Text>}
      {term.length >= 2 && !query.isFetching && query.data?.length === 0 && (
        <Text style={styles.empty}>Nenhum jogo encontrado</Text>
      )}

      <FlatList
        data={query.data ?? []}
        keyExtractor={(item) => String(item.igdbId)}
        renderItem={renderItem}
        contentContainerStyle={styles.list}
      />
    </View>
  );
}

const styles = StyleSheet.create({
  container: { flex: 1, padding: 16 },
  input: { borderWidth: 1, borderColor: '#ccc', borderRadius: 8, padding: 12, fontSize: 16, marginBottom: 12 },
  spinner: { marginVertical: 8 },
  error: { color: '#dc2626', marginVertical: 8 },
  empty: { color: '#666', marginVertical: 8 },
  list: { gap: 12 },
  row: { flexDirection: 'row', gap: 12, alignItems: 'center' },
  cover: { width: 48, height: 64, borderRadius: 6, backgroundColor: '#eee' },
  coverPlaceholder: { alignItems: 'center', justifyContent: 'center' },
  rowInfo: { flex: 1 },
  rowTitle: { fontSize: 16, fontWeight: '600' },
  rowSubtitle: { fontSize: 13, color: '#666', marginTop: 2 },
});
