import { Platform } from 'react-native';

/**
 * No web, o FormData é o nativo do navegador e exige um Blob/File de verdade —
 * anexar o objeto {uri, name, type} (que funciona no React Native) só vira
 * "[object Object]" e o backend recebe a requisição sem arquivo nenhum.
 * No nativo, mantém o shape que o React Native já sabe resolver pela uri local.
 */
export async function appendFileToFormData(formData: FormData, fieldName: string, uri: string, filename: string, mimeType: string) {
  if (Platform.OS === 'web') {
    const response = await fetch(uri);
    const blob = await response.blob();
    formData.append(fieldName, blob, filename);
    return;
  }

  // @ts-expect-error -- React Native's FormData aceita esse shape de arquivo, diferente do DOM
  formData.append(fieldName, { uri, name: filename, type: mimeType });
}
