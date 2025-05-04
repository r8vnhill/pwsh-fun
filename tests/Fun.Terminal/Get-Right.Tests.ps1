BeforeAll {
    # Load shared test setup logic (e.g., type definitions, helpers)
    . (Join-Path $PSScriptRoot 'Setup.ps1')

    # Custom assertion function to check if the result is a Right monad
    function Assert-RightResult {
        param (
            [Parameter(Mandatory, ValueFromPipeline)]
            $result,
            
            [Parameter(Mandatory)]
            $expectedValue
        )

        # The result must be marked as a successful Right
        $result.IsRight | Should -Be $true

        # The wrapped value must exactly match the expected one
        $result.Value | Should -BeExactly $expectedValue
    }
}

# Define data-driven test cases using different kinds of input values
Describe 'Get-Right' -ForEach @(
    @{ value = 420 },
    @{ value = 'Rasengan' },
    @{ value = @(1, 2, 3) },
    @{ value = @{ a = 1; b = 2 } }
) {

    # Test case: Direct invocation with -Value parameter
    Context 'when packaging a value inside the monadic context' {
        It 'returns <value> wrapped in a monad' {
            # Act: Call Get-Right with a value
            $monad = Get-Right -Value $value

            # Assert: It should be a Right monad containing the value
            Assert-RightResult $monad $value
        }
    }

    # Test case: Using pipeline input
    Context 'when using pipeline input' {

        It 'wraps the piped value in a Right' {
            # Use unary comma to prevent array decomposition in the pipeline
            ,$value | Get-Right | Assert-RightResult -expectedValue $value
        }

        It 'wraps each item in a Right when piping multiple values' {
            # Pipe multiple values — each one should be wrapped individually
            $results = @(1, 2, 3) | Get-Right

            # Verify that 3 monads were returned
            $results.Count | Should -Be 3

            # Each result should be a Right containing the corresponding value
            for ($i = 0; $i -lt $results.Count; $i++) {
                Assert-RightResult $results[$i] ($i + 1)
            }
        }
    }

    # Test case: Invalid input (null or empty string)
    Context 'when given invalid input' {
        It 'throws when given $null' {
            # Null values are rejected due to ValidateNotNullOrEmpty
            { Get-Right -Value $null } | Should -Throw
        }

        It 'throws when given empty string' {
            # Empty strings are also rejected
            { Get-Right -Value '' } | Should -Throw
        }
    }
}
