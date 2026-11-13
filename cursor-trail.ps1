param(
    [string]$Color = "00FFFF", 
    [int]$Length = 5
)

$code = @"
using System;
using System.Collections.Generic;
using System.Diagnostics;
using System.Drawing;
using System.Drawing.Drawing2D;
using System.Drawing.Imaging;
using System.Runtime.InteropServices;
using System.Windows.Forms;

public class TrailForm : Form
{
    public string TrailColorHex = "$Color"; 
    public int TrailLength = $Length;       
    
    const float CoreWidth  = 3.5f;  
    const float GlowWidth  = 11f;   
    const int   GlowAlpha  = 60;    

    const int WS_EX_TRANSPARENT = 0x20;
    const int WS_EX_TOOLWINDOW  = 0x80;
    const int WS_EX_LAYERED     = 0x80000;
    const int WS_EX_NOACTIVATE  = 0x8000000;

    [StructLayout(LayoutKind.Sequential)]
    struct BLENDFUNCTION { public byte BlendOp, BlendFlags, SourceConstantAlpha, AlphaFormat; }

    [DllImport("user32.dll", SetLastError = true)]
    static extern bool UpdateLayeredWindow(IntPtr hwnd, IntPtr hdcDst, ref Point pptDst, ref Size psize,
        IntPtr hdcSrc, ref Point pptSrc, int crKey, ref BLENDFUNCTION pblend, int dwFlags);
    [DllImport("user32.dll")] static extern IntPtr GetDC(IntPtr hWnd);
    [DllImport("user32.dll")] static extern int ReleaseDC(IntPtr hWnd, IntPtr hDC);
    [DllImport("gdi32.dll")] static extern IntPtr CreateCompatibleDC(IntPtr hDC);
    [DllImport("gdi32.dll")] static extern bool DeleteDC(IntPtr hdc);
    [DllImport("gdi32.dll")] static extern IntPtr SelectObject(IntPtr hDC, IntPtr hObject);
    [DllImport("gdi32.dll")] static extern bool DeleteObject(IntPtr hObject);

    List<Point> pts = new List<Point>();
    List<long> times = new List<long>();
    Point last = new Point(-99999, -99999);
    bool cleared = false;
    Stopwatch sw = Stopwatch.StartNew();
    System.Windows.Forms.Timer timer = new System.Windows.Forms.Timer();
    
    int LifeMs;
    Color BaseColor;

    public TrailForm()
    {
        FormBorderStyle = FormBorderStyle.None;
        ShowInTaskbar = false;
        TopMost = true;
        StartPosition = FormStartPosition.Manual;
        Location = new Point(0, 0);
        Size = new Size(1, 1);

        TrailLength = Math.Max(1, Math.Min(10, TrailLength)); 
        
        LifeMs = 50 + ((TrailLength - 1) * 200); 
        
        try { 
            string fullHex = TrailColorHex.StartsWith("#") ? TrailColorHex : "#" + TrailColorHex;
            BaseColor = ColorTranslator.FromHtml(fullHex); 
        } 
        catch { BaseColor = Color.Cyan; }

        timer.Interval = 8;
        timer.Tick += OnTick;
        timer.Start();
    }

    protected override CreateParams CreateParams
    {
        get
        {
            CreateParams cp = base.CreateParams;
            cp.ExStyle |= WS_EX_TRANSPARENT | WS_EX_TOOLWINDOW | WS_EX_LAYERED | WS_EX_NOACTIVATE;
            return cp;
        }
    }

    protected override bool ShowWithoutActivation { get { return true; } }

    void OnTick(object s, EventArgs e)
    {
        long now = sw.ElapsedMilliseconds;
        Point p = Cursor.Position;
        if (p != last) { pts.Add(p); times.Add(now); last = p; }

        while (times.Count > 0 && now - times[0] > LifeMs) { pts.RemoveAt(0); times.RemoveAt(0); }
        Render(now);
    }

    void Render(long now)
    {
        int n = pts.Count;
        if (n < 2)
        {
            if (!cleared)
            {
                using (Bitmap empty = new Bitmap(1, 1, PixelFormat.Format32bppArgb))
                    Present(empty, new Point(0, 0));
                cleared = true;
            }
            return;
        }
        cleared = false;

        int pad = (int)GlowWidth + 3;
        int minX = int.MaxValue, minY = int.MaxValue, maxX = int.MinValue, maxY = int.MinValue;
        foreach (Point q in pts)
        {
            if (q.X < minX) minX = q.X; if (q.X > maxX) maxX = q.X;
            if (q.Y < minY) minY = q.Y; if (q.Y > maxY) maxY = q.Y;
        }
        int ox = minX - pad, oy = minY - pad;
        int w = maxX - minX + pad * 2 + 1, h = maxY - minY + pad * 2 + 1;

        using (Bitmap bmp = new Bitmap(w, h, PixelFormat.Format32bppArgb))
        {
            using (Graphics g = Graphics.FromImage(bmp))
            {
                g.SmoothingMode = SmoothingMode.AntiAlias;
                g.Clear(Color.Transparent);

                for (int pass = 0; pass < 2; pass++)
                {
                    for (int i = 1; i < n; i++)
                    {
                        float f = 1f - (float)(now - times[i]) / LifeMs;   
                        if (f <= 0f) continue;
                        float width = (pass == 0 ? GlowWidth : CoreWidth) * f;   
                        int alpha = pass == 0 ? (int)(GlowAlpha * f) : (int)(255 * f);
                        if (width < 0.5f || alpha < 1) continue;
                        
                        using (Pen pen = new Pen(Color.FromArgb(alpha, BaseColor.R, BaseColor.G, BaseColor.B), width))
                        {
                            pen.StartCap = LineCap.Flat;
                            pen.EndCap = LineCap.Flat;
                            g.DrawLine(pen, pts[i - 1].X - ox, pts[i - 1].Y - oy, pts[i].X - ox, pts[i].Y - oy);
                        }
                    }
                }
            }
            Present(bmp, new Point(ox, oy));
        }
    }

    void Present(Bitmap bmp, Point dst)
    {
        IntPtr screenDc = GetDC(IntPtr.Zero);
        IntPtr memDc = CreateCompatibleDC(screenDc);
        IntPtr hBmp = bmp.GetHbitmap(Color.FromArgb(0));
        IntPtr old = SelectObject(memDc, hBmp);
        try
        {
            Size size = new Size(bmp.Width, bmp.Height);
            Point src = new Point(0, 0);
            BLENDFUNCTION bf = new BLENDFUNCTION();
            bf.BlendOp = 0; bf.BlendFlags = 0; bf.SourceConstantAlpha = 255; bf.AlphaFormat = 1;
            UpdateLayeredWindow(Handle, screenDc, ref dst, ref size, memDc, ref src, 0, ref bf, 2);
        }
        finally
        {
            SelectObject(memDc, old);
            DeleteObject(hBmp);
            DeleteDC(memDc);
            ReleaseDC(IntPtr.Zero, screenDc);
        }
    }
}
"@

Add-Type -TypeDefinition $code -ReferencedAssemblies System.Windows.Forms, System.Drawing

[System.Windows.Forms.Application]::EnableVisualStyles()
$form = New-Object TrailForm

$tray = New-Object System.Windows.Forms.NotifyIcon
$tray.Icon = [System.Drawing.SystemIcons]::Application
$tray.Text = "Cursor Trail"
$menu = New-Object System.Windows.Forms.ContextMenuStrip
$exit = $menu.Items.Add("Exit")
$exit.add_Click({ $tray.Visible = $false; $tray.Dispose(); $form.Close() })
$tray.ContextMenuStrip = $menu
$tray.Visible = $true

[System.Windows.Forms.Application]::Run($form)
