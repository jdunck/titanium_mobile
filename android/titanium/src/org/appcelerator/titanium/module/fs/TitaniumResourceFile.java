/**
 * Appcelerator Titanium Mobile
 * Copyright (c) 2009 by Appcelerator, Inc. All Rights Reserved.
 * Licensed under the terms of the Apache Public License
 * Please see the LICENSE included with this distribution for details.
 */

package org.appcelerator.titanium.module.fs;

import java.io.IOException;
import java.io.InputStream;
import java.lang.ref.SoftReference;

import org.appcelerator.titanium.api.ITitaniumFile;
import org.appcelerator.titanium.api.ITitaniumFilesystem;

import android.content.Context;
import org.appcelerator.titanium.config.TitaniumConfig;

public class TitaniumResourceFile extends TitaniumBaseFile
{
	@SuppressWarnings("unused")
	private static final String LCAT = "TiResourceFile";
	@SuppressWarnings("unused")
	private static final boolean DBG = TitaniumConfig.LOGD;

	private final ITitaniumFilesystem filesystem;
	private final SoftReference<Context> softContext;
	private final String path;

	public TitaniumResourceFile(ITitaniumFilesystem filesystem, Context context, String path)
	{
		super(TYPE_RESOURCE);
		this.filesystem = filesystem;
		this.softContext = new SoftReference<Context>(context);
		this.path = path;
	}

	@Override
	public ITitaniumFile resolve()
	{
		return this;
	}

	@Override
	public void write(String data, boolean append) throws IOException
	{
		throw new IOException("read only");
	}

	@Override
	public String read() throws IOException
	{
		StringBuilder builder=new StringBuilder();
		InputStream in = null;
		try
		{
			Context context = softContext.get();
			if (context != null) {
				in = context.getAssets().open("Resources/"+path);
				byte buffer [] = new byte[4096];
				while(true)
				{
					int count = in.read(buffer);
					if (count < 0)
					{
						break;
					}
					builder.append(new String(buffer,0,count));
				}
			}
		}
		finally
		{
			if (in!=null)
			{
				in.close();
			}
		}
		return builder.toString();
	}

	public boolean copy(String destination)
	{
		//NOTE: this isn't really efficient but not sure
		//if there's a better way with the different file
		//abstractions

		try
		{
			String data = read();
			ITitaniumFile dest = filesystem.getFile(new String[]{destination});
			dest.write(data,false);

			return dest.exists();
		}
		catch(Exception ig)
		{
			return false;
		}
	}

	@Override
	public boolean exists()
	{
		return true;
	}

	@Override
	public String name()
	{
		int idx = path.lastIndexOf("/");
		if (idx != -1)
		{
			return path.substring(idx);
		}
		return path;
	}

	@Override
	public String extension()
	{
		int idx = path.lastIndexOf(".");
		if (idx != -1)
		{
			return path.substring(idx+1);
		}
		return null;
	}

	@Override
	public String nativePath()
	{
		return toString();
	}
	public double size()
	{
		return 0L;
	}
	public double spaceAvailable()
	{
		return 99999999L;
	}
	public boolean createShortcut()
	{
		return false;
	}
	public boolean setExecutable()
	{
		return false;
	}
	public boolean setReadonly()
	{
		return false;
	}
	public boolean setWriteable()
	{
		return false;
	}
	public void unzip (String destination)
	{
	}
	public String toString ()
	{
		return getPath();
	}


	// OUTSIDE OF THE API
	String getPath()
	{
		return path;
	}
}
