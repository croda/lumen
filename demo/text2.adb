with ada.text_io;   use ada.text_io;
-- Simple Lumen demo/test program to illustrate how to display text, using the
-- texture-mapped font facility.

with Ada.Characters.Latin_1;
with Ada.Command_Line;
with Ada.Strings.Fixed;
with Ada.Float_Text_IO;

with Lumen.Events.Animate;
with Lumen.Window;

with Lumen.Font.Txf;
with Lumen.GL;
with Lumen.GLU;

use Lumen;

procedure Text2 is

   ---------------------------------------------------------------------------

   -- Rotation wraps around at this point, in degrees
   Max_Rotation      : constant := 359;

   -- Nice peppy game-style framerate, in frames per second
   Framerate         : constant := 60;

   -- A font to fall back on
   Default_Font_Path : constant String := "fsb.txf";

   ---------------------------------------------------------------------------

   Win      : Window.Handle;
   Direct   : Boolean := True;  -- want direct rendering by default
   Event    : Events.Event_Data;
   Wide     : Natural := 400;
   High     : Natural := 400;
   Img_Wide : Float;
   Img_High : Float;
   Rotation : Natural := 0;
   Rotating : Boolean := True;
   Tx_Font  : Font.Txf.Handle;
   Object   : GL.UInt;
   Frame    : Natural := 0;

   Attrs    : Window.Context_Attributes :=
      (
       (Window.Attr_Red_Size,    8),
       (Window.Attr_Green_Size,  8),
       (Window.Attr_Blue_Size,   8),
       (Window.Attr_Alpha_Size,  8),
       (Window.Attr_Depth_Size, 24)
      );

   ---------------------------------------------------------------------------

   Program_Error : exception;
   Program_Exit  : exception;

   ---------------------------------------------------------------------------

   -- Return number blank-padded on the left out to Width; returns full
   -- number if it's wider than Width.
   function Img (Number : in Integer;
                 Width  : in Positive := 1) return String is

      use Ada.Strings.Fixed;

      Image : String := Trim (Integer'Image (Number), Side => Ada.Strings.Left);

   begin  -- Img
      if Image'Length >= Width then
         return Image;
      else
         return ((Width - Image'Length) * ' ') & Image;
      end if;
   end Img;

   ---------------------------------------------------------------------------

   -- Set or reset the window view parameters
   procedure Set_View (W, H : in Natural) is

      Aspect : GL.Double;

   begin  -- Set_View

      -- Viewport dimensions
      GL.Viewport (0, 0, GL.SizeI (W), GL.SizeI (H));

      -- Size of rectangle upon which text is displayed
      if Wide > High then
         Img_Wide := 1.0;
         Img_High := Float (High) / Float (Wide);
      else
         Img_Wide := Float (Wide) / Float (High);
         Img_High := 1.0;
      end if;

      -- Set up the projection matrix based on the window's shape--wider than
      -- high, or higher than wide
      GL.MatrixMode (GL.GL_PROJECTION);
      GL.LoadIdentity;

      -- Set up a 3D viewing frustum, which is basically a truncated pyramid
      -- in which the scene takes place.  Roughly, the narrow end is your
      -- screen, and the wide end is 10 units away from the camera.
      if W <= H then
         Aspect := GL.Double (H) / GL.Double (W);
         GL.Frustum (-1.0, 1.0, -Aspect, Aspect, 2.0, 10.0);
      else
         Aspect := GL.Double (W) / GL.Double (H);
         GL.Frustum (-Aspect, Aspect, -1.0, 1.0, 2.0, 10.0);
      end if;

   end Set_View;

   ---------------------------------------------------------------------------

   -- Draw our scene
   procedure Draw is

      use type GL.Bitfield;

      MW    : Natural;
      MA    : Natural;
      MD    : Natural;
      Scale : Float;
      Pad   : Float := Img_Wide / 10.0;  -- margin width

      FNum  : String := Img (Frame, 6);
      FRate : String (1 .. 6);

   begin  -- Draw

      -- Set a light grey background
      GL.ClearColor (0.85, 0.85, 0.85, 0.0);
      GL.Clear (GL.GL_COLOR_BUFFER_BIT or GL.GL_DEPTH_BUFFER_BIT);

      -- Draw a black rectangle, disabling texturing so we can do plain colors
      GL.Disable (GL.GL_TEXTURE_2D);
      GL.Disable (GL.GL_BLEND);
      GL.Disable (GL.GL_ALPHA_TEST);
      GL.Color (Float (0.0), 0.0, 0.0);
      GL.glBegin (GL.GL_POLYGON);
      begin
         GL.Vertex (-Img_Wide, -Img_High, 0.0);
         GL.Vertex (-Img_Wide,  Img_High, 0.0);
         GL.Vertex ( Img_Wide,  Img_High, 0.0);
         GL.Vertex ( Img_Wide, -Img_High, 0.0);
      end;
      GL.glEnd;

      -- Turn texturing back on and set up to draw the text messages
      GL.PushMatrix;
      GL.Enable (GL.GL_TEXTURE_2D);
      GL.Enable (GL.GL_ALPHA_TEST);
      GL.AlphaFunc (GL.GL_GEQUAL, 0.0625);
      GL.Enable (GL.GL_BLEND);
      GL.BlendFunc (GL.GL_SRC_ALPHA, GL.GL_ONE_MINUS_SRC_ALPHA);
      GL.Enable (GL.GL_POLYGON_OFFSET_FILL);
      GL.PolygonOffset (0.0, -3.0);
      GL.Color (Float (0.1), 0.8, 0.1);

      -- Draw the frame number, right-justified in upper half of rectangle
      GL.PushMatrix;
      Font.Txf.Get_String_Metrics (Tx_Font, FNum, MW, MA, MD);
      Scale := Img_High / (Float (MA) * 3.0);
      GL.Translate (Img_Wide - (Pad + Float (MW) * Scale), Float (MA) * Scale, 0.0);
      GL.Scale (Scale, Scale, Scale);
      Font.Txf.Render (Tx_Font, FNum);
      GL.PopMatrix;

      -- Draw the frame number label, left-justified in upper half of
      -- rectangle, and one-third the size of the number itself
      GL.PushMatrix;
      Font.Txf.Get_String_Metrics (Tx_Font, "Frame", MW, MA, MD);
      GL.Translate (-(Img_Wide - Pad), Float (MA) * Scale, 0.0);
      GL.Scale (Scale / 3.0, Scale / 3.0, Scale / 3.0);
      Font.Txf.Render (Tx_Font, "Frame");
      GL.PopMatrix;

      -- Draw the frame rate, right-justified in lower half of rectangle
      GL.PushMatrix;
      -- Guard against out-of-range values, and display all question marks if so
      begin
         Ada.Float_Text_IO.Put (FRate, Events.Animate.FPS (Win), Aft => 3, Exp => 0);

      exception
         when others =>
            FRate := (others => '?');
      end;
      Font.Txf.Get_String_Metrics (Tx_Font, FRate, MW, MA, MD);
      GL.Translate (Img_Wide - (Pad + Float (MW) * Scale), -Float (MA) * Scale, 0.0);
      GL.Scale (Scale, Scale, Scale);
      Font.Txf.Render (Tx_Font, FRate);
      GL.PopMatrix;

      -- Draw the frame rate label, left-justified in lower half of
      -- rectangle, and one-third the size of the number itself
      GL.PushMatrix;
      Font.Txf.Get_String_Metrics (Tx_Font, "FPS", MW, MA, MD);
      GL.Translate (-(Img_Wide - Pad), -Float (MA) * Scale, 0.0);
      GL.Scale (Scale / 3.0, Scale / 3.0, Scale / 3.0);
      Font.Txf.Render (Tx_Font, "FPS");
      GL.PopMatrix;

      GL.PopMatrix;

      -- Rotate the object around the Y and Z axes by the current amount, to
      -- give a "tumbling" effect.
      GL.MatrixMode (GL.GL_MODELVIEW);
      GL.LoadIdentity;
      GL.Translate (GL.Double (0.0), 0.0, -4.0);
      GL.Rotate (GL.Double (Rotation), 0.0, 1.0, 0.0);
      GL.Rotate (GL.Double (Rotation), 0.0, 0.0, 1.0);

      -- Now show it
      Window.Swap (Win);

   end Draw;

   ---------------------------------------------------------------------------

   -- Simple event handler routine for close-window events
   procedure Quit_Handler (Event : in Events.Event_Data) is
   begin  -- Quit_Handler
      raise Program_Exit;
   end Quit_Handler;

   ---------------------------------------------------------------------------

   -- Simple event handler routine for keypresses
   procedure Key_Handler (Event : in Events.Event_Data) is

      use type Events.Key_Symbol;

   begin  -- Key_Handler
      if Event.Key_Data.Key = Events.To_Symbol (Ada.Characters.Latin_1.ESC) or
         Event.Key_Data.Key = Events.To_Symbol ('q') then
         raise Program_Exit;
      elsif Event.Key_Data.Key = Events.To_Symbol (Ada.Characters.Latin_1.Space) then
         Rotating := not Rotating;
      end if;
   end Key_Handler;

   ---------------------------------------------------------------------------

   -- Simple event handler routine for Exposed events
   procedure Expose_Handler (Event : in Events.Event_Data) is
   begin  -- Expose_Handler
      Draw;
   end Expose_Handler;

   ---------------------------------------------------------------------------

   -- Simple event handler routine for Resized events
   procedure Resize_Handler (Event : in Events.Event_Data) is
   begin  -- Resize_Handler
      Wide := Event.Resize_Data.Width;
      High := Event.Resize_Data.Height;
      Set_View (Wide, High);
      Draw;
   end Resize_Handler;

   ---------------------------------------------------------------------------

   -- Our draw-a-frame routine, should get called FPS times a second
   procedure New_Frame (Frame_Delta : in Duration) is
   begin  -- New_Frame
      if Rotating then
         if Rotation >= Max_Rotation then
            Rotation := 0;
         else
            Rotation := Rotation + 1;
         end if;
      end if;

      Frame := Frame + 1;

      Draw;
   end New_Frame;

   ---------------------------------------------------------------------------

begin  -- Text2

   -- Load the font we'll be using
   if Ada.Command_Line.Argument_Count > 0 then
      declare
         Font_Path : String := Ada.Command_Line.Argument (1);
      begin
         Font.Txf.Load (Tx_Font, Font_Path);

      exception
         when others =>
            raise Program_Error with "cannot find font file """ & Font_Path & """";
      end;
   else
      begin
         Font.Txf.Load (Tx_Font, Default_Font_Path);
      exception
         when others =>
            begin
               Font.Txf.Load (Tx_Font, "demo/" & Default_Font_Path);
            exception
               when others =>
                  raise Program_Error with "cannot find default font file """ & Default_Font_Path & """";
            end;
      end;
   end if;

   -- If other command-line arguments were given then process them
   for Index in 2 .. Ada.Command_Line.Argument_Count loop

      declare
         use Window;
         Arg : String := Ada.Command_Line.Argument (Index);
      begin
         case Arg (Arg'First) is

            when 'a' =>
               Attrs (4) := (Attr_Alpha_Size, Integer'Value (Arg (Arg'First + 1 .. Arg'Last)));

            when 'c' =>
               Attrs (1) := (Attr_Red_Size,   Integer'Value (Arg (Arg'First + 1 .. Arg'Last)));
               Attrs (2) := (Attr_Blue_Size,  Integer'Value (Arg (Arg'First + 1 .. Arg'Last)));
               Attrs (3) := (Attr_Green_Size, Integer'Value (Arg (Arg'First + 1 .. Arg'Last)));

            when 'd' =>
               Attrs (5) := (Attr_Depth_Size, Integer'Value (Arg (Arg'First + 1 .. Arg'Last)));

            when 'n' =>
               Direct := False;

            when others =>
               null;

         end case;
      end;

   end loop;

   -- Create Lumen window, accepting most defaults; turn double buffering off
   -- for simplicity
   Window.Create (Win,
                  Name       => "Text Demo #2, Revenge of the Text",
                  Width      => Wide,
                  Height     => High,
                  Direct     => Direct,
                  Attributes => Attrs,
                  Events     => (Window.Want_Key_Press => True,
                                 Window.Want_Exposure  => True,
                                 others => False));

   -- Set up the viewport and scene parameters
   Set_View (Wide, High);
   Object := Font.Txf.Establish_Texture (Tx_Font, 0, True);

   -- Enter the event loop
   declare
      use Events;
   begin
      Animate.Select_Events (Win   => Win,
                             Calls => (Key_Press    => Key_Handler'Unrestricted_Access,
                                       Exposed      => Expose_Handler'Unrestricted_Access,
                                       Resized      => Resize_Handler'Unrestricted_Access,
                                       Close_Window => Quit_Handler'Unrestricted_Access,
                                       others       => No_Callback),
                             FPS   => Framerate,
                             Frame => New_Frame'Unrestricted_Access);
   end;

exception
   when Program_Exit =>
      null;  -- just exit this block, which terminates the app

end Text2;
