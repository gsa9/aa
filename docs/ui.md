# ui.md
**Windows Forms UI Design Guidelines**

---

## Purpose

Defines standard UI patterns for Windows Forms interfaces in the clinical patient data management system. Read this document (rui) BEFORE creating or modifying any Windows Forms UI.

**When to read**: Creating new windows | Modifying UI/layout | Adding form elements

**Not needed for**: Business logic changes | Database operations | Cryptography updates

**Once per conversation**: Context persists after first read

---

## Form Properties Standard

All forms MUST use these baseline properties:

```powershell
$form = New-Object System.Windows.Forms.Form
$form.Text = "Clinical Database - [Specific Function]"
$form.Size = New-Object System.Drawing.Size(450, 280)  # Adjust as needed
$form.StartPosition = "CenterScreen"
$form.FormBorderStyle = "FixedDialog"
$form.MaximizeBox = $false
```

**Dialog forms** (modal, single-purpose):
```powershell
$form.MinimizeBox = $false  # Prevent minimize on modal dialogs
```

**Main application windows** (main menu, patient management):
```powershell
$form.MinimizeBox = $true   # Allow minimize on main windows
```

**Rationale**:
- CenterScreen: Professional appearance, consistent positioning
- FixedDialog: Prevents resizing (controls stay positioned correctly)
- MaximizeBox false: Dialog-style interface (not a full application window)
- MinimizeBox based on context: Modal dialogs should not minimize

---

## Positioning System

**ALWAYS use Y-position tracking for vertical layout**:

```powershell
$yPos = 10  # Start position

# Title
$titleLabel.Location = New-Object System.Drawing.Point(10, $yPos)
$form.Controls.Add($titleLabel)
$yPos += 40  # Move down for next control

# Next control
$nextControl.Location = New-Object System.Drawing.Point(10, $yPos)
$form.Controls.Add($nextControl)
$yPos += 30  # Move down again
```

**Vertical spacing standards**:
- Title to first section: 40-50px
- Between input fields: 30px
- Between sections: 40px
- Before buttons: 40px
- Between buttons (stacked): 50px

**Horizontal positioning**:
- Form margins: 10px from edges
- Label width: 120px (consistent for all labels)
- Input field start: 140px (10px margin + 120px label + 10px gap)
- Input field width: Calculate from form width minus margins
  - Example: 450px form = 280px input (450 - 140 - 30)
- Buttons: Right-aligned or centered based on context
  - Dialog buttons (OK/Cancel): Right-aligned with 10px gap
  - Action buttons (main menu): Centered with consistent width

**Rationale**:
- Y-position tracking allows flexible layouts (dev mode indicators, conditional sections)
- Consistent spacing creates professional, readable interface
- Standard widths ensure alignment across all forms

---

## Typography Standards

**Title labels** (form header):
```powershell
$titleLabel.Font = New-Object System.Drawing.Font("Arial", 12, [System.Drawing.FontStyle]::Bold)
```

**Section separators** (logical groupings):
```powershell
$sectionLabel.Font = New-Object System.Drawing.Font("Arial", 9, [System.Drawing.FontStyle]::Bold)
```

**Standard labels** (field labels):
```powershell
# Use default font (no explicit Font property)
$label.Text = "Username:"
```

**User info displays** (main menu, status bars):
```powershell
$userLabel.Font = New-Object System.Drawing.Font("Arial", 10, [System.Drawing.FontStyle]::Bold)
```

**Rationale**:
- Clear hierarchy: Title (12pt bold) > Section (9pt bold) > Labels (default)
- Arial font family: Professional, highly readable on Windows
- Consistent sizing across all forms

---

## Color Standards

**Dev mode indicators**:
```powershell
$devLabel.ForeColor = [System.Drawing.Color]::Orange
$devLabel.Text = "[DEV MODE] Using workgroup security"
```

**Error messages**: Use MessageBox with Error icon (red X icon, system handles color)

**Success messages**: Use MessageBox with Information icon (blue i icon, system handles color)

**Standard controls**: Use default system colors (no explicit color properties)

**Rationale**:
- Orange for dev mode: High visibility without alarm (not red)
- System colors for standard controls: Windows theme compatibility
- MessageBox icons provide standard visual feedback

---

## Input Controls

**Text input fields**:
```powershell
$textBox = New-Object System.Windows.Forms.TextBox
$textBox.Location = New-Object System.Drawing.Point(140, $yPos)
$textBox.Size = New-Object System.Drawing.Size(280, 20)
$form.Controls.Add($textBox)
```

**Password fields**:
```powershell
$passwordBox = New-Object System.Windows.Forms.TextBox
$passwordBox.Location = New-Object System.Drawing.Point(140, $yPos)
$passwordBox.Size = New-Object System.Drawing.Size(280, 20)
$passwordBox.PasswordChar = '*'
$form.Controls.Add($passwordBox)
```

**Labels for inputs**:
```powershell
$label = New-Object System.Windows.Forms.Label
$label.Location = New-Object System.Drawing.Point(10, $yPos)
$label.Size = New-Object System.Drawing.Size(120, 20)
$label.Text = "Field Name:"
$form.Controls.Add($label)
```

**Label text format**: Always end with colon (":"), capitalize first letter

**Rationale**:
- Consistent sizing ensures visual alignment
- PasswordChar '*' is standard Windows convention
- 120px label width accommodates most field names without truncation

---

## Button Standards

**Dialog buttons** (OK/Cancel pairs):
```powershell
# OK/Submit button
$okButton = New-Object System.Windows.Forms.Button
$okButton.Location = New-Object System.Drawing.Point(230, $yPos)
$okButton.Size = New-Object System.Drawing.Size(90, 30)
$okButton.Text = "OK"  # or "Login", "Submit", etc.
$okButton.DialogResult = [System.Windows.Forms.DialogResult]::OK
$form.Controls.Add($okButton)
$form.AcceptButton = $okButton  # Enter key triggers this button

# Cancel button (10px gap from OK button)
$cancelButton = New-Object System.Windows.Forms.Button
$cancelButton.Location = New-Object System.Drawing.Point(330, $yPos)
$cancelButton.Size = New-Object System.Drawing.Size(90, 30)
$cancelButton.Text = "Cancel"
$cancelButton.DialogResult = [System.Windows.Forms.DialogResult]::Cancel
$form.Controls.Add($cancelButton)
$form.CancelButton = $cancelButton  # Escape key triggers this button
```

**Action buttons** (main menu, feature access):
```powershell
$actionButton = New-Object System.Windows.Forms.Button
$actionButton.Location = New-Object System.Drawing.Point(100, $yPos)  # Centered for 500px form
$actionButton.Size = New-Object System.Drawing.Size(300, 40)
$actionButton.Text = "Manage Patients"
$actionButton.Add_Click({
    # Action handler
})
$form.Controls.Add($actionButton)
```

**Button sizing**:
- Dialog buttons: 90x30 (compact, side-by-side)
- Action buttons: 300x40 (prominent, centered, stacked)

**Button text**:
- Use action verbs: "Login", "Create", "Save", "Cancel", "Logout"
- Sentence case: "Manage Patients" (not "MANAGE PATIENTS" or "manage patients")

**AcceptButton/CancelButton**:
- ALWAYS set AcceptButton (Enter key default action)
- ALWAYS set CancelButton (Escape key cancels dialog)

**Rationale**:
- 90x30 buttons fit side-by-side in 450px forms with proper spacing
- 300x40 buttons are prominent for main actions
- DialogResult integration provides clean dialog handling
- AcceptButton/CancelButton improve keyboard usability

---

## Dialog Patterns

**Modal dialog with result**:
```powershell
function Show-InputDialog {
    param()

    $form = New-Object System.Windows.Forms.Form
    # ... form setup ...

    # Show form and get result
    $result = $form.ShowDialog()

    if ($result -eq [System.Windows.Forms.DialogResult]::OK) {
        # Collect input
        $data = $textBox.Text.Trim()

        # Validate
        if ([string]::IsNullOrWhiteSpace($data)) {
            [System.Windows.Forms.MessageBox]::Show("Field cannot be empty.", "Validation Error", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Error)
            $form.Dispose()
            return $null
        }

        # Return collected data
        $form.Dispose()
        return @{
            Data = $data
        }
    }

    # User cancelled
    $form.Dispose()
    return $null
}
```

**Application window (non-modal)**:
```powershell
function Show-MainMenu {
    param(
        [Parameter(Mandatory = $true)]
        [hashtable]$user,

        [Parameter(Mandatory = $true)]
        [System.Data.OleDb.OleDbConnection]$connection
    )

    $menuForm = New-Object System.Windows.Forms.Form
    # ... form setup ...

    # Button handlers
    $actionButton.Add_Click({
        [System.Windows.Forms.MessageBox]::Show("Feature not yet implemented.", "Not Implemented", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Information)
    })

    # Show form (blocks until closed)
    $menuForm.ShowDialog() | Out-Null
    $menuForm.Dispose()
}
```

**ALWAYS dispose forms**:
```powershell
$form.Dispose()  # At every exit point (success, cancel, error)
```

**Rationale**:
- ShowDialog() blocks execution (modal behavior)
- DialogResult provides clean success/cancel handling
- Validation happens before returning data
- Dispose prevents resource leaks
- Return $null on cancel for easy null checking

---

## Validation and Error Handling

**Input validation pattern**:
```powershell
if ([string]::IsNullOrWhiteSpace($textBox.Text)) {
    [System.Windows.Forms.MessageBox]::Show(
        "Username cannot be empty.",
        "Validation Error",
        [System.Windows.Forms.MessageBoxButtons]::OK,
        [System.Windows.Forms.MessageBoxIcon]::Error
    )
    $form.Dispose()
    return $null
}
```

**MessageBox standards**:
- Title: Concise description ("Validation Error", "Login Failed", "Success")
- Message: Specific, actionable feedback
- Buttons: OK for acknowledgment, YesNo for confirmation
- Icon: Error (red X), Information (blue i), Warning (yellow triangle), Question (blue ?)

**Validation timing**:
- Validate AFTER dialog closes (user clicked OK)
- Show error MessageBox immediately after validation fails
- Dispose form and return $null after error
- Caller should check for $null and handle appropriately

**Rationale**:
- Clear, immediate feedback to user
- Standard Windows dialog appearance
- Consistent error handling pattern across all forms

---

## Conditional UI Elements

**Dev mode indicator** (shown only in dev mode):
```powershell
# Dev mode indicator
if (Test-DevMode) {
    $devLabel = New-Object System.Windows.Forms.Label
    $devLabel.Location = New-Object System.Drawing.Point(10, 40)
    $devLabel.Size = New-Object System.Drawing.Size(410, 20)
    $devLabel.ForeColor = [System.Drawing.Color]::Orange
    $devLabel.Text = "[DEV MODE] Using workgroup security"
    $form.Controls.Add($devLabel)
    $yPos = 70  # Adjust starting position for other controls
}
else {
    $yPos = 50  # Standard starting position
}

# Continue layout from $yPos
```

**Role-based buttons** (admin-only features):
```powershell
if ($user.Role -eq "admin") {
    $adminButton = New-Object System.Windows.Forms.Button
    $adminButton.Location = New-Object System.Drawing.Point(100, $yPos)
    $adminButton.Size = New-Object System.Drawing.Size(300, 40)
    $adminButton.Text = "Manage Users"
    $adminButton.Add_Click({ /* handler */ })
    $form.Controls.Add($adminButton)

    $yPos += 50  # Move down for next control
}

# Continue layout from $yPos
```

**Pattern**: Always adjust $yPos after conditional elements

**Rationale**:
- Y-position tracking handles conditional layout automatically
- Dev mode indicator always visible in dev mode (important context)
- Role-based UI provides appropriate access (security through UI and backend)

---

## Form-Level Keyboard Capture

**Pattern**: Capture keyboard input directly at form level without visible input controls.

**Use cases**:
- Cryptic login interfaces (security through obscurity)
- Custom keyboard handling (shortcuts, navigation)
- Invisible input capture (no visible TextBox)

**Implementation approach**:
1. Enable form keyboard preview: `$form.KeyPreview = $true`
2. Handle KeyDown event for special keys (Enter, Escape, Backspace, Tab)
3. Handle KeyPress event for character input (letters, numbers, symbols)
4. Track input state manually (current field, accumulated characters)

**CRITICAL - Script Scope Requirement**:

Event handlers create new scope - state variables MUST use `$script:` prefix to persist across event invocations.

**Problem**: Without script scope, `$variable +=` creates local copy per event
- Result: Only last character kept, not full sequence

**Solution**: Declare state variables with `$script:` prefix
- `$script:currentInput = ""`
- `$script:inputState = 0`

**Pattern applies to**:
- Accumulated text input (`$script:currentInput += $char`)
- State machines (`$script:inputState = 1`)
- Flags (`$script:inputFrozen = $true`)

**KeyDown vs KeyPress**:
- KeyDown: Special keys (Enter, Escape, Backspace, arrow keys)
  - Use `$e.KeyCode` enum comparison
  - Call `$e.SuppressKeyPress = $true` to prevent beep/default action
- KeyPress: Character input (printable characters)
  - Use `$e.KeyChar` to get character
  - Check `[int][char]$e.KeyChar` for control characters (<32)
  - Call `$e.Handled = $true` to mark event as handled

**Rationale**:
- Avoids TextBox size limitations (zero-size controls don't receive input)
- Direct form-level capture works regardless of focus
- Script scope ensures state persists across event invocations
- Clean separation: KeyDown for control flow, KeyPress for data

**Reference**: See login UI implementation for complete example

---

## Section Separators

**Logical grouping with separator labels**:
```powershell
# Section separator
$sectionLabel = New-Object System.Windows.Forms.Label
$sectionLabel.Location = New-Object System.Drawing.Point(10, $yPos)
$sectionLabel.Size = New-Object System.Drawing.Size(410, 20)
$sectionLabel.Font = New-Object System.Drawing.Font("Arial", 9, [System.Drawing.FontStyle]::Bold)
$sectionLabel.Text = "KEK Password (for patient data encryption)"
$form.Controls.Add($sectionLabel)

$yPos += 25  # Separator to first field in section: 25px

# Fields in this section
# ...
```

**Use separators when**:
- Grouping related fields (user credentials vs. KEK password)
- Providing context for a section (explanation in parentheses)
- Separating logical workflow steps

**Rationale**:
- Clear visual hierarchy (bold, larger font)
- Improves form readability
- Provides helpful context inline (no need for external help text)

---

## Quick Reference

**Standard form (450px width)**:
```powershell
$form = New-Object System.Windows.Forms.Form
$form.Text = "Clinical Database - Feature"
$form.Size = New-Object System.Drawing.Size(450, 280)
$form.StartPosition = "CenterScreen"
$form.FormBorderStyle = "FixedDialog"
$form.MaximizeBox = $false
$form.MinimizeBox = $false  # or $true for main windows

$yPos = 10

# Title
$titleLabel = New-Object System.Windows.Forms.Label
$titleLabel.Location = New-Object System.Drawing.Point(10, $yPos)
$titleLabel.Size = New-Object System.Drawing.Size(410, 30)
$titleLabel.Font = New-Object System.Drawing.Font("Arial", 12, [System.Drawing.FontStyle]::Bold)
$titleLabel.Text = "Form Title"
$form.Controls.Add($titleLabel)
$yPos += 40

# Input field
$fieldLabel = New-Object System.Windows.Forms.Label
$fieldLabel.Location = New-Object System.Drawing.Point(10, $yPos)
$fieldLabel.Size = New-Object System.Drawing.Size(120, 20)
$fieldLabel.Text = "Field Name:"
$form.Controls.Add($fieldLabel)

$fieldBox = New-Object System.Windows.Forms.TextBox
$fieldBox.Location = New-Object System.Drawing.Point(140, $yPos)
$fieldBox.Size = New-Object System.Drawing.Size(280, 20)
$form.Controls.Add($fieldBox)
$yPos += 30

# Buttons
$okButton = New-Object System.Windows.Forms.Button
$okButton.Location = New-Object System.Drawing.Point(230, $yPos)
$okButton.Size = New-Object System.Drawing.Size(90, 30)
$okButton.Text = "OK"
$okButton.DialogResult = [System.Windows.Forms.DialogResult]::OK
$form.Controls.Add($okButton)
$form.AcceptButton = $okButton

$cancelButton = New-Object System.Windows.Forms.Button
$cancelButton.Location = New-Object System.Drawing.Point(330, $yPos)
$cancelButton.Size = New-Object System.Drawing.Size(90, 30)
$cancelButton.Text = "Cancel"
$cancelButton.DialogResult = [System.Windows.Forms.DialogResult]::Cancel
$form.Controls.Add($cancelButton)
$form.CancelButton = $cancelButton

# Show and handle result
$result = $form.ShowDialog()
if ($result -eq [System.Windows.Forms.DialogResult]::OK) {
    # Process input
}
$form.Dispose()
```

**Key measurements**:
- Form width: 450px (dialogs), 500px (main windows)
- Margins: 10px
- Label width: 120px
- Input start: 140px
- Input width: 280px (for 450px form)
- Button size: 90x30 (dialog), 300x40 (action)
- Vertical gaps: 30px (fields), 40px (sections)

---

## Reference Implementation

**See**: gui_login.ps1 (comprehensive example with all patterns)

**Key features demonstrated**:
- Y-position tracking for flexible layout
- Dev mode conditional UI
- Section separators with context
- Multiple input fields (text and password)
- Dialog button pair (Login/Cancel)
- Input validation with MessageBox
- DialogResult handling
- Form disposal at all exit points
- Main menu with role-based UI
- Action buttons with placeholders

---

**Summary**: Follow these patterns for ALL Windows Forms UI. Consistency creates professional, maintainable interface.
