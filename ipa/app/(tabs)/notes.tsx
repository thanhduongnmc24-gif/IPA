import React, { useState, useRef, useCallback } from 'react';
import { 
  StyleSheet, Text, View, TouchableOpacity, FlatList, Modal, TextInput, 
  Platform, KeyboardAvoidingView, ScrollView, Animated, Keyboard, LayoutAnimation, UIManager 
} from 'react-native';
import { SafeAreaView } from 'react-native-safe-area-context';
import { Ionicons } from '@expo/vector-icons';
import AsyncStorage from '@react-native-async-storage/async-storage';
import { useTheme } from '../context/ThemeContext';
import { GestureHandlerRootView, Swipeable, RectButton } from 'react-native-gesture-handler';
import * as WebBrowser from 'expo-web-browser';
import { useFocusEffect } from 'expo-router';

// Kích hoạt LayoutAnimation cho Android để list nhảy mượt hơn
if (Platform.OS === 'android') {
  if (UIManager.setLayoutAnimationEnabledExperimental) {
    UIManager.setLayoutAnimationEnabledExperimental(true);
  }
}

type QuickNote = {
  id: string;
  title: string;
  content: string;
  date: string;
  isPinned?: boolean; // [MỚI] Thêm trạng thái ghim
};

export default function NotesScreen() {
  const { colors } = useTheme();
  const [notes, setNotes] = useState<QuickNote[]>([]);
  const [modalVisible, setModalVisible] = useState(false);
  const [editingId, setEditingId] = useState<string | null>(null);
  const [title, setTitle] = useState('');
  const [content, setContent] = useState('');
  
  const [searchQuery, setSearchQuery] = useState('');

  const rowRefs = useRef<Map<string, Swipeable>>(new Map());

  useFocusEffect(
    useCallback(() => {
      loadNotes();
    }, [])
  );

  const loadNotes = async () => {
    try {
      const data = await AsyncStorage.getItem('QUICK_NOTES');
      if (data) {
          let loadedNotes = JSON.parse(data);
          // Sắp xếp lại khi load để đảm bảo pin luôn ở đầu
          loadedNotes = sortNotes(loadedNotes);
          setNotes(loadedNotes);
      }
    } catch (e) {}
  };

  // [MỚI] Hàm sắp xếp: Đưa Pinned lên đầu
  const sortNotes = (list: QuickNote[]) => {
      return list.sort((a, b) => {
          // Nếu a ghim mà b không ghim -> a lên trước (-1)
          if (a.isPinned && !b.isPinned) return -1;
          // Nếu b ghim mà a không ghim -> b lên trước (1)
          if (!a.isPinned && b.isPinned) return 1;
          // Còn lại giữ nguyên thứ tự (hoặc theo ngày nếu muốn)
          return 0;
      });
  };

  const saveNotes = async (newNotes: QuickNote[]) => {
    try {
      // Luôn sắp xếp trước khi lưu
      const sortedNotes = sortNotes(newNotes);
      await AsyncStorage.setItem('QUICK_NOTES', JSON.stringify(sortedNotes));
      
      // Hiệu ứng chuyển động mượt mà
      LayoutAnimation.configureNext(LayoutAnimation.Presets.easeInEaseOut);
      setNotes(sortedNotes);
    } catch (e) {}
  };

  const handleOpenModal = (note?: QuickNote) => {
    if (note) {
      setEditingId(note.id);
      setTitle(note.title);
      setContent(note.content);
    } else {
      setEditingId(null);
      setTitle('');
      setContent('');
    }
    setModalVisible(true);
  };

  const handleSave = () => {
    if (!title.trim() && !content.trim()) {
      setModalVisible(false); return;
    }
    let updatedNotes = [...notes];
    
    if (editingId) {
      // Khi sửa, giữ nguyên trạng thái isPinned cũ
      updatedNotes = updatedNotes.map(n => 
          n.id === editingId ? { ...n, title, content } : n
      );
    } else {
      // Ghi chú mới mặc định không ghim
      const newNote = { 
          id: Date.now().toString(), 
          title, 
          content, 
          date: new Date().toLocaleDateString('vi-VN'),
          isPinned: false 
      };
      // Thêm vào đầu danh sách (nhưng sau các items đã Pin nhờ hàm sort ở saveNotes)
      updatedNotes = [newNote, ...updatedNotes];
    }
    saveNotes(updatedNotes);
    setModalVisible(false);
  };

  // [MỚI] Hàm xử lý Ghim/Bỏ ghim
  const togglePin = (id: string) => {
      const updatedNotes = notes.map(n => 
          n.id === id ? { ...n, isPinned: !n.isPinned } : n
      );
      saveNotes(updatedNotes);
      
      // Đóng swipe nếu đang mở
      if (rowRefs.current.has(id)) {
          rowRefs.current.get(id)?.close();
      }
  };

  const handleDelete = (id: string) => {
    const updatedNotes = notes.filter(n => n.id !== id);
    saveNotes(updatedNotes);
    if (rowRefs.current.has(id)) {
        rowRefs.current.get(id)?.close();
        rowRefs.current.delete(id);
    }
  };

  const handlePressLink = async (text: string) => {
    if (text.startsWith('http')) {
        try {
            await WebBrowser.openBrowserAsync(text, {
                controlsColor: colors.primary,
                toolbarColor: colors.card,
                presentationStyle: WebBrowser.WebBrowserPresentationStyle.FULL_SCREEN
            });
        } catch (error) {
            console.log("Không thể mở trình duyệt:", error);
        }
    }
  };

  const filteredNotes = notes.filter(n => {
    const searchLower = searchQuery.toLowerCase();
    return (
        (n.title && n.title.toLowerCase().includes(searchLower)) ||
        (n.content && n.content.toLowerCase().includes(searchLower))
    );
  });

  const renderItem = ({ item }: { item: QuickNote }) => {
    const isLink = item.title.startsWith('http');

    const renderRightActions = (progress: any, dragX: any) => {
      const scale = dragX.interpolate({
        inputRange: [-100, 0],
        outputRange: [1, 0],
        extrapolate: 'clamp',
      });
      return (
        <RectButton style={styles.deleteAction} onPress={() => handleDelete(item.id)}>
          <Animated.View style={{ transform: [{ scale }], alignItems: 'center' }}>
             <Ionicons name="trash-bin" size={24} color="white" />
             <Text style={{color:'white', fontWeight:'bold', fontSize: 12, marginTop: 4}}>Xóa</Text>
          </Animated.View>
        </RectButton>
      );
    };

    return (
      <View style={styles.noteWrapper}>
        <Swipeable
          ref={ref => { if (ref && !rowRefs.current.has(item.id)) rowRefs.current.set(item.id, ref); }}
          renderRightActions={renderRightActions}
          overshootRight={false}
          containerStyle={{borderRadius: 12, overflow: 'hidden'}} 
        >
          {/* [MỚI] Thêm viền nếu là Pinned */}
          <View style={[
              styles.card, 
              { 
                  backgroundColor: item.isPinned ? (colors.theme === 'dark' ? '#312e81' : '#EEF2FF') : colors.card, 
                  borderColor: item.isPinned ? colors.primary : colors.border,
                  borderWidth: item.isPinned ? 1.5 : 1
              }
          ]}>
            
            <View style={styles.titleSection}>
               {/* Phần tiêu đề */}
               {isLink ? (
                  <TouchableOpacity onPress={() => handlePressLink(item.title)} style={{flex: 1}}>
                      <Text numberOfLines={1} style={[styles.cardTitle, { color: colors.primary, textDecorationLine: 'underline' }]}>
                        {item.title} 🔗
                      </Text>
                  </TouchableOpacity>
               ) : (
                  <View style={{flex: 1}}>
                    <Text numberOfLines={1} style={[styles.cardTitle, { color: colors.text }]}>
                       {item.title || '(Không tiêu đề)'}
                    </Text>
                  </View>
               )}
               
               {/* Ngày tháng */}
               <Text style={{fontSize: 11, color: colors.subText, marginLeft: 10, marginRight: 10}}>{item.date}</Text>
               
               {/* [MỚI] Nút PIN */}
               <TouchableOpacity onPress={() => togglePin(item.id)} style={{padding: 4}}>
                   <Ionicons 
                      name={item.isPinned ? "push-pin" : "push-pin-outline"} 
                      size={20} 
                      color={item.isPinned ? colors.primary : colors.subText} 
                   />
               </TouchableOpacity>
            </View>

            <View style={[styles.divider, {backgroundColor: colors.border}]} />

            <TouchableOpacity style={styles.contentSection} activeOpacity={0.7} onPress={() => handleOpenModal(item)}>
               <Text numberOfLines={2} style={{color: colors.subText, fontSize: 14, lineHeight: 20}}>
                  {item.content || 'Chạm vào đây để viết nội dung...'}
               </Text>
            </TouchableOpacity>

          </View>
        </Swipeable>
      </View>
    );
  };

  return (
    <GestureHandlerRootView style={{ flex: 1, backgroundColor: colors.bg }}>
      <SafeAreaView style={{flex: 1}} edges={['top']}>
        
        {/* HEADER */}
        <View style={styles.header}>
          <Text style={[styles.headerTitle, {color: colors.text}]}>Ghi Chú 📝</Text>
          <TouchableOpacity onPress={() => handleOpenModal()} style={[styles.addBtn, {backgroundColor: colors.primary}]}>
            <Ionicons name="add" size={24} color="white" />
          </TouchableOpacity>
        </View>

        {/* THANH TÌM KIẾM */}
        <View style={{paddingHorizontal: 20, marginBottom: 10}}>
            <View style={[styles.searchBar, {backgroundColor: colors.iconBg, borderColor: colors.border}]}>
                <Ionicons name="search" size={20} color={colors.subText} />
                <TextInput 
                    style={[styles.searchInput, {color: colors.text}]}
                    placeholder="Tìm tiêu đề hoặc nội dung..." 
                    placeholderTextColor={colors.subText}
                    value={searchQuery}
                    onChangeText={setSearchQuery}
                />
                {searchQuery.length > 0 && (
                    <TouchableOpacity onPress={() => {setSearchQuery(''); Keyboard.dismiss();}}>
                        <Ionicons name="close-circle" size={20} color={colors.subText} />
                    </TouchableOpacity>
                )}
            </View>
        </View>

        <FlatList 
          data={filteredNotes} 
          renderItem={renderItem} 
          keyExtractor={i => i.id} 
          contentContainerStyle={{padding: 20, paddingBottom: 100, paddingTop: 5}}
          ListEmptyComponent={
             <Text style={{textAlign:'center', color: colors.subText, marginTop: 50}}>
                {searchQuery ? 'Không tìm thấy kết quả nào.' : 'Trống trơn. Bấm dấu + để thêm.'}
             </Text>
          }
        />

        <Modal visible={modalVisible} animationType="slide" transparent>
          <KeyboardAvoidingView behavior={Platform.OS === "ios" ? "padding" : "height"} style={styles.modalOverlay}>
            <View style={[styles.modalContent, {backgroundColor: colors.card, borderColor: colors.border}]}>
              <View style={styles.modalHeader}>
                <Text style={{fontSize:18, fontWeight:'bold', color: colors.text}}>
                    {editingId ? 'Sửa ghi chú' : 'Ghi chú mới'}
                </Text>
                <TouchableOpacity onPress={() => setModalVisible(false)}><Ionicons name="close" size={24} color={colors.text}/></TouchableOpacity>
              </View>
              
              <ScrollView style={{ flex: 1 }}>
                <Text style={[styles.label, {color: colors.subText}]}>Tiêu đề (hoặc Link):</Text>
                <TextInput style={[styles.input, {backgroundColor: colors.iconBg, color: colors.text}]} placeholder="http://... hoặc Tiêu đề" placeholderTextColor={colors.subText} value={title} onChangeText={setTitle} />
                
                <Text style={[styles.label, {color: colors.subText}]}>Nội dung:</Text>
                <TextInput style={[styles.input, {backgroundColor: colors.iconBg, color: colors.text, height: 200, textAlignVertical:'top'}]} placeholder="Chi tiết..." placeholderTextColor={colors.subText} multiline value={content} onChangeText={setContent} />
              </ScrollView>
              
              <TouchableOpacity onPress={handleSave} style={[styles.saveBtn, {backgroundColor: colors.primary}]}>
                  <Text style={{color:'white', fontWeight:'bold'}}>Lưu lại</Text>
              </TouchableOpacity>
            </View>
          </KeyboardAvoidingView>
        </Modal>
      </SafeAreaView>
    </GestureHandlerRootView>
  );
}

const styles = StyleSheet.create({
  header: { flexDirection: 'row', justifyContent: 'space-between', alignItems: 'center', paddingHorizontal: 20, paddingVertical: 15, paddingBottom: 10 },
  headerTitle: { fontSize: 24, fontWeight: 'bold' },
  addBtn: { width: 40, height: 40, borderRadius: 20, justifyContent: 'center', alignItems: 'center' },
  searchBar: { flexDirection: 'row', alignItems: 'center', paddingHorizontal: 12, paddingVertical: 8, borderRadius: 12, borderWidth: 1, marginBottom: 5 },
  searchInput: { flex: 1, marginLeft: 10, fontSize: 15, height: 30 },
  noteWrapper: { marginBottom: 12 },
  card: { },
  titleSection: { padding: 12, paddingBottom: 8, flexDirection: 'row', justifyContent: 'space-between', alignItems: 'center' },
  cardTitle: { fontSize: 16, fontWeight: 'bold' },
  divider: { height: 1, width: '100%', opacity: 0.5 },
  contentSection: { padding: 12, paddingTop: 8, minHeight: 60, justifyContent: 'center' },
  deleteAction: { backgroundColor: '#EF4444', justifyContent: 'center', alignItems: 'center', width: 80, height: '100%' },
  modalOverlay: { flex: 1, backgroundColor: 'rgba(0,0,0,0.5)', justifyContent: 'flex-end' },
  modalContent: { borderTopLeftRadius: 20, borderTopRightRadius: 20, padding: 20, borderWidth: 1, height: '80%', display: 'flex', flexDirection: 'column' },
  modalHeader: { flexDirection: 'row', justifyContent: 'space-between', marginBottom: 20 },
  label: { marginBottom: 5, fontSize: 12, fontWeight: '600' },
  input: { borderRadius: 10, padding: 12, marginBottom: 15 },
  saveBtn: { padding: 15, borderRadius: 12, alignItems: 'center', marginTop: 10 },
});
