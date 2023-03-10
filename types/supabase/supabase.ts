export type Json =
  | string
  | number
  | boolean
  | null
  | { [key: string]: Json }
  | Json[]

export interface Database {
  public: {
    Tables: {
      profiles: {
        Row: {
          avatar: string | null
          id: string
          name: string | null
        }
        Insert: {
          avatar?: string | null
          id: string
          name?: string | null
        }
        Update: {
          avatar?: string | null
          id?: string
          name?: string | null
        }
      }
      profiles_private: {
        Row: {
          admin: boolean
          email: unknown | null
          id: string
          phone: string | null
        }
        Insert: {
          admin?: boolean
          email?: unknown | null
          id: string
          phone?: string | null
        }
        Update: {
          admin?: boolean
          email?: unknown | null
          id?: string
          phone?: string | null
        }
      }
    }
    Views: {
      [_ in never]: never
    }
    Functions: {
      citext:
        | {
            Args: { "": string }
            Returns: unknown
          }
        | {
            Args: { "": boolean }
            Returns: unknown
          }
        | {
            Args: { "": unknown }
            Returns: unknown
          }
      citext_hash: {
        Args: { "": unknown }
        Returns: number
      }
      citextin: {
        Args: { "": unknown }
        Returns: unknown
      }
      citextout: {
        Args: { "": unknown }
        Returns: unknown
      }
      citextrecv: {
        Args: { "": unknown }
        Returns: unknown
      }
      citextsend: {
        Args: { "": unknown }
        Returns: string
      }
      get_is_admin: {
        Args: Record<PropertyKey, never>
        Returns: boolean
      }
    }
    Enums: {
      [_ in never]: never
    }
  }
}
