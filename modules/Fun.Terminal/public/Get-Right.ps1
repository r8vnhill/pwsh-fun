<#
.SYNOPSIS
Creates a new Right instance representing a successful result.

.DESCRIPTION
Wraps a value in a [Right] Either instance, indicating a successful computation.
Useful for functional-style return handling in scripts.

.PARAMETER Value
The value to wrap as a successful result.

.OUTPUTS
[Either]

.EXAMPLE
Get-Right -Value "Success"
#>
function Get-Right {
    [OutputType([Either])]
    [CmdletBinding()]
    param (
        [Parameter(Mandatory, ValueFromPipeline)]
        [ValidateNotNullOrEmpty()]
        [object]$Value
    )

    process {
        Write-Output ([Either]::Right($Value))
    }
}

<#
.SYNOPSIS
Represents a discriminated union type that can hold either a success value (Right) or a failure value (Left).

.DESCRIPTION
The `Either` class is a base class for functional-style error handling.
It distinguishes between successful computations (`Right`) and error states (`Left`).
It includes helper methods for creating instances (`Right()`, `Left()`), transforming values with `Map()`, and converting to string with `ToString()`.

The `IsRight` property indicates whether the instance is a Right value (success) or a Left value (error).
The `Value` property contains the wrapped data (either the success or the error).

.NOTES
This structure allows chaining and transformation without throwing exceptions, promoting explicit and composable error handling.
#>
class Either {
    
    [bool]$IsRight
    [object]$Value

    <#
    .SYNOPSIS
    Initializes a new instance of the Either type.
    
    .PARAMETER isRight
    Indicates whether the instance represents a Right (true) or Left (false) value.

    .PARAMETER value
    The value to store inside the Either instance.
    #>
    Either([bool]$isRight, [object]$value) {
        $this.IsRight = $isRight
        $this.Value = $value
    }

    <#
    .SYNOPSIS
    Creates a new Right instance representing a successful result.

    .PARAMETER value
    The success value to wrap.

    .OUTPUTS
    Right
    #>
    static [Either] Right([object]$value) {
        return [Either]::new($true, $value)
    }

    <#
    .SYNOPSIS
    Creates a new Left instance representing a failure or error result.

    .PARAMETER value
    The error value to wrap.

    .OUTPUTS
    Left
    #>
    static [Either] Left([object]$value) {
        return [Either]::new($false, $value)
    }

    <#
    .SYNOPSIS
    Applies a transformation to the wrapped value if it is a Right, leaving Left untouched.

    .PARAMETER func
    A script block that transforms the current value.

    .OUTPUTS
    Either
    #>
    [Either] Map([ScriptBlock]$func) {
        return $this.IsRight ? $func.Invoke($this.Value) : $this
    }

    <#
    .SYNOPSIS
    Returns a string representation of the Either instance.

    .OUTPUTS
    String
    #>
    [string] ToString() {
        return $this.IsRight ? "Right: $($this.Value)" : "Left: $($this.Value)"
    }
}
