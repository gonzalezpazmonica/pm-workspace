package com.savia.data.local.dao

import androidx.room.Dao
import androidx.room.Insert
import androidx.room.OnConflictStrategy
import androidx.room.Query
import com.savia.data.local.entity.SavedOutputEntity
import kotlinx.coroutines.flow.Flow

/**
 * Data Access Object for saved Claude outputs.
 *
 * Provides CRUD operations for outputs that users save from
 * assistant messages (code snippets, reports, action items, etc.).
 */
@Dao
interface SavedOutputDao {

    /** Get all saved outputs, newest first. */
    @Query("SELECT * FROM saved_outputs ORDER BY createdAt DESC")
    fun getAll(): Flow<List<SavedOutputEntity>>

    /** Get saved outputs filtered by type (e.g., "code", "markdown"). */
    @Query("SELECT * FROM saved_outputs WHERE type = :type ORDER BY createdAt DESC")
    fun getByType(type: String): Flow<List<SavedOutputEntity>>

    /** Get all saved outputs for a specific conversation. */
    @Query("SELECT * FROM saved_outputs WHERE conversationId = :conversationId ORDER BY createdAt DESC")
    fun getByConversation(conversationId: String): Flow<List<SavedOutputEntity>>

    /** Get favorite outputs for quick access. */
    @Query("SELECT * FROM saved_outputs WHERE isFavorite = 1 ORDER BY createdAt DESC")
    fun getFavorites(): Flow<List<SavedOutputEntity>>

    /** Insert or replace a saved output. */
    @Insert(onConflict = OnConflictStrategy.REPLACE)
    suspend fun insert(output: SavedOutputEntity)

    /** Toggle favorite status. */
    @Query("UPDATE saved_outputs SET isFavorite = NOT isFavorite WHERE id = :id")
    suspend fun toggleFavorite(id: String)

    /** Delete a saved output by ID. */
    @Query("DELETE FROM saved_outputs WHERE id = :id")
    suspend fun delete(id: String)

    /** Count of all saved outputs. */
    @Query("SELECT COUNT(*) FROM saved_outputs")
    suspend fun getCount(): Int
}
