import { ChangeEventHandler, useCallback, useEffect, useState } from 'react';
import Image from "next/image";
import { useSupabase } from "#/hooks/useSupabase";
import { useUser } from "@supabase/auth-helpers-react";

export interface Props {
  url?: string,
  onUpload: (path: string) => void
}

export const EditAvatar = ({ url, onUpload }: Props) => {
  const [ avatarUrl, setAvatarUrl ] = useState<string | null>(null);
  const [ uploading, setUploading ] = useState(false);
  const [ downloading, setDownloading ] = useState(false);
  const supabase = useSupabase();
  const user = useUser();

  const downloadImage = useCallback(async (path: string) => {
    try {
      const { data, error } = await supabase.storage
        .from('avatars')
        .download(path);
      if (error) {
        return console.log('Error downloading image: ', error.message);
      }
      const url = URL.createObjectURL(data!);
      setAvatarUrl(url);
    } catch (error: any) {
      console.log('Error downloading image: ', error.message);
    }
  }, [ supabase.storage ]);

  useEffect(() => {
    if (url && !avatarUrl && !downloading) {
      setDownloading(true);
      downloadImage(url)
        .catch(console.error)
        .finally(() => setDownloading(false));
    }
  }, [ downloadImage, url, avatarUrl, downloading ]);


  const uploadAvatar: ChangeEventHandler<HTMLInputElement> = useCallback(async (event) => {
    if (!user?.id) {
      return;
    }
    try {
      setUploading(true);

      if (!event.target.files || event.target.files.length === 0) {
        throw new Error('You must select an image to upload.');
      }

      const file = event.target.files[0];
      const fileExt = file.name.split('.').pop();
      const fileName = `${Math.random()}.${fileExt}`;
      const filePath = `${fileName}`;

      let { error: uploadError } = await supabase.storage
        .from('avatars')
        .upload(filePath, file);

      if (uploadError) {
        throw uploadError;
      }

      let { error: insertError } = await supabase.from("profiles")
        .update({ avatar: filePath })
        .eq("id", user.id);

      if (insertError) {
        throw insertError;
      }

      onUpload(filePath);
    } catch (error: any) {
      // TODO: this is a garbage way to let the user know that this failed.
      alert(error.message);
    } finally {
      setUploading(false);
    }
  }, [ onUpload, supabase, user?.id ]);

  return (
    <div className='space-y-8'>
      {avatarUrl ? (
        <Image
          width={45}
          height={45}
          src={avatarUrl}
          alt="Avatar"
          className="w-16 h-16 rounded-full border object-cover"
        />
      ) : (
        <div className="w-16 h-16 border rounded-full" />
      )}
      <div>
        <label className="btn" htmlFor="single">
          {uploading ? 'Uploading…' : 'Change'}
        </label>
        <input
          style={{
            visibility: 'hidden',
            position: 'absolute'
          }}
          type="file"
          id="single"
          accept="image/*"
          onChange={uploadAvatar}
          disabled={uploading}
        />
      </div>
    </div>
  );
};
